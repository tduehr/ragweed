require ::File.join(::File.dirname(__FILE__),'wraptux')
## Modeled after wraposx written by tduehr

module Ragweed; end

## Debugger class for Linux
## You can use this class in 2 ways:
##
## (1) You can create instances of Debuggertux and use them to set and handle
##     breakpoints.
##
## (2) If you want to do more advanced event handling, you can subclass from
##     debugger and define your own on_whatever events. If you handle an event
##     that Debuggertux already handles, call "super", too.
class Ragweed::Debuggertux
  # include Ragweed

  attr_reader :pid
  attr_reader :status
  attr_reader :exited
  attr_accessor :breakpoints

  ## Class to handle installing/uninstalling breakpoints
  class Breakpoint

    INT3 = 0xCC ## obviously x86 specific debugger here

    attr_accessor :orig
    attr_reader :addr
    attr_accessor :function

    ## bp: parent for method_missing calls
    ## ip: insertion point
    ## callable: lambda to be called when breakpoint is hit
    ## name: name of breakpoint
    def initialize(bp, ip, callable, p, name = "")
	  @bppid = p
      @@bpid ||= 0
      @bp = bp
      @function = name
      @addr = ip
      @callable = callable
      @installed = false
      @orig = 0
      @bpid = (@@bpid += 1)
    end

    ## Install a breakpoint (replace instruction with int3)
    def install
      ## Replace the original instruction with an int3
      @orig = Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::PEEK_TEXT, @bppid, @addr, 0)
      if @orig != -1
        n = (@orig & ~0xff) | INT3;
        Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::POKE_TEXT, @bppid, @addr, n)
        @installed = true
      else
        @installed = false
      end
    end

    ## Uninstall the breakpoint
    def uninstall
      ## Put back the original instruction
      if @orig != INT3
        Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::POKE_TEXT, @bppid, @addr, @orig)
        @installed = false
      end
    end

    def installed?; @installed; end
    def call(*args); @callable.call(*args) if @callable != nil; end
    def method_missing(meth, *args); @bp.send(meth, *args); end
  end ## Breakpoint Class

  ## init object
  ## p: pid of process to be debugged
  ## opts: default options for automatically doing things (attach and install)
  def initialize(pid,opts={}) ## Debuggertux Class
    if p.to_i.kind_of? Fixnum
      @pid = pid.to_i
    else
      raise "Provide a PID"
    end

    @opts = opts

    default_opts(opts)
    @installed = false
    @attached = false

    ## Store all breakpoints in this hash
    @breakpoints = Hash.new do |h, k|
        bps = Array.new
        def bps.call(*args); each {|bp| bp.call(*args)}; end
        def bps.install; each {|bp| bp.install}; end
        def bps.uninstall; each {|bp| bp.uninstall}; end
        def bps.orig; each {|bp| dp.orig}; end
        h[k] = bps
    end
    @opts.each {|k, v| try(k) if v}
  end

  ## This is crude!
  def self.find_by_regex(rx)
    a = Dir.entries("/proc/")
    a.delete_if do |x| x == '.'; end
    a.delete_if do |x| x == '..'; end
    a.delete_if do |x| x =~ /[a-z]/; end
    a.each do |x|
      f = File.read("/proc/#{x}/cmdline")
      if f =~ rx
        return x
      end
    end
	return nil
  end

  def install_bps
    @breakpoints.each do |k,v|
      v.install
    end
    @installed = true
  end

  def uninstall_bps
    @breakpoints.each do |k,v|
      v.uninstall
    end
    @installed = false
  end

  ## Attach calls install_bps so dont forget to call breakpoint_set
  ## BEFORE attach or explicitly call install_bps
  def attach(opts=@opts)
    r = Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::ATTACH, @pid, 0, 0)
    if r != -1
        @attached = true
        on_attach
        ## Temporarily gross until I figure this one out
        sleep(0.5)
        self.install_bps if (opts[:install] and not @installed)
    else
        raise "Attach failed!"
    end
  end

  def continue
    on_continue
    Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::CONTINUE, @pid, 0, 0)
  end

  def detach
    on_detach
    Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::DETACH, @pid, 0, 0)
  end

  def stepp
	on_stepp
    ret = Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::STEP, @pid, 1, 0)
  end

  ## Adds a breakpoint to be installed
  ## ip: Insertion point
  ## name: name of breakpoint
  ## callable: object to .call at breakpoint
  def breakpoint_set(ip, name="", callable=nil, &block)
    if not callable and block_given?
      callable = block
    end
    @breakpoints[ip] << Breakpoint.new(self, ip, callable, @pid, name)
  end

  ## remove breakpoint with id bpid at insertion point or
  ## remove all breakpoints at insertion point if bpid not given
  ## ip: Insertion point
  ## bpid: id of breakpoint to be removed
  def breakpoint_clear(ip, bpid=nil)
    if not bpid
      @breakpoints[ip].uninstall
      @breakpoints[ip].delete ip
    else
      found = nil
      @breakpoints[ip].each_with_index do |bp, i|
        if bp.bpid == bpid
          found = i
          if bp.orig != Breakpoint::INT3
            if @breakpoints[op][i+1]
              @breakpoints[ip][i + 1].orig = bp.orig
            else
              bp.uninstall
            end
          end
        end
      end
      raise "could not find bp ##{bpid} at ##{ip}" if not found
      @breakpoints[ip].delete_at(found) if found
    end
  end

  ##loop for wait()
  ##times: the number of wait calls to make
  ##       if nil loop will continue indefinitely
  def loop(times=nil)
    if times.kind_of? Numeric
      times.times do
        self.wait
      end
    elsif times.nil?
      self.wait while not @exited
    end
  end

  ## This wait must be smart, it has to wait for a signal
  ## when SIGTRAP is received we need to see if one of our
  ## breakpoints has fired. If it has then execute the block
  ## originally stored with it. If its a different signal,
  ## then process it accordingly and move on
  def wait(opts = 0)
    r = Ragweed::Wraptux::waitpid(@pid,opts)
    status = r[1]
    wstatus = status & 0x7f
    signal = status >> 8
    found = false
    if r[0] != 0    ## Check the ret
      case  ## FIXME - I need better logic (use Signal module)
      when wstatus == 0 ##WIFEXITED
        @exited = true
        self.on_exit
      when wstatus != 0x7f ##WIFSIGNALED
        @exited = false
        self.on_signal
      when signal == Ragweed::Wraptux::Signal::SIGINT
        self.continue
      when signal == Ragweed::Wraptux::Signal::SIGSEGV
        self.on_segv
      when signal == Ragweed::Wraptux::Signal::SIGILL
        self.on_illegalinst
      when signal == Ragweed::Wraptux::Signal::SIGTRAP
        ## Check if EIP matches a breakpoint we have set
        r = self.get_registers
        eip = r[:eip]
        eip -= 1
        if @breakpoints.has_key?(eip)
          found = true
          self.on_breakpoint
        else
          puts "We got a SIGTRAP but not at our breakpoint... continuing"
        end
        self.continue
      when signal == Ragweed::Wraptux::Signal::SIGTERM
        self.on_sigterm
      when signal == Ragweed::Wraptux::Signal::SIGCONT
        self.continue
      when signal == Ragweed::Wraptux::Signal::SIGSTOP
        self.continue
	  when signal == Ragweed::Wraptux::Signal::SIGWINCH
		self.continue
      else
        raise "Add more signal handlers (##{signal})"
      end
    end
  end

  ## Return an array of thread PIDs
  def self.threads(pid)
	begin
	    a = Dir.entries("/proc/#{pid}/task/")
	rescue
		puts "No such process (#{pid})"
		return
	end
    a.delete_if { |x| x == '.' }
    a.delete_if { |x| x == '..' }
  end

  ## Gets the registers for the given process
  def get_registers
    size = Ragweed::Wraptux::SIZEOFLONG * 17
    regs = Array.new(size)
    regs = regs.to_ptr
    regs.struct!('LLLLLLLLLLLLLLLLL', :ebx,:ecx,:edx,:esi,:edi,:ebp,:eax,:xds,:xes,:xfs,:xgs,:orig_eax,:eip,:xcs,:eflags,:esp,:xss)
    Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::GETREGS, @pid, 0, regs.to_i)
    return regs
  end

  ## Sets registers for the given process
  def set_registers(r)
    Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::SETREGS, @pid, 0, r.to_i)
  end

  ## Here we need to do something about the bp
  ## we just hit. We have a block to execute
  def on_breakpoint
    r = self.get_registers
    eip = r[:eip]
    eip -= 1

    ## Call the block associated with the breakpoint
    @breakpoints[eip].call(r, self)

    if @breakpoints[eip].first.installed?
      @breakpoints[eip].first.uninstall
      r[:eip] = eip
      set_registers(r)
      stepp
      ## ptrace peektext returns -1 upon reinstallation of bp without calling
      ## waitpid() if that occurs the breakpoint cannot be reinstalled
      Ragweed::Wraptux::waitpid(@pid, 0)
      @breakpoints[eip].first.install
    end
  end

  def print_regs
    regs = self.get_registers
    puts "eip %08x" % regs[:eip]
    puts "esi %08x" % regs[:esi]
    puts "edi %08x" % regs[:edi]
    puts "esp %08x" % regs[:esp]
    puts "eax %08x" % regs[:eax]
    puts "ebx %08x" % regs[:ebx]
    puts "ecx %08x" % regs[:ecx]
    puts "edx %08x" % regs[:edx]
  end

  def on_exit
    #puts "process exited"
  end

  def on_illegalinst
    #puts "illegal instruction"
  end

  def on_attach
    #puts "attached to process"
  end

  def on_detach
    #puts "process detached"
  end

  def on_sigterm
    #puts "process terminated"
  end

  def on_continue
    #puts "process continued"
  end

  def on_stopped
    #puts "process stopped"
  end

  def on_signal
    #puts "process received signal"
  end

  def on_stepp
    #puts "single stepping"
  end

  def on_segv
    #print_regs
    #exit
  end

  def default_opts(opts)
    @opts = @opts.merge(opts)
  end
end
