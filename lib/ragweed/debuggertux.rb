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
  attr_reader :pid, :status, :exited
  attr_accessor :breakpoints, :mapped_regions

  ## Class to handle installing/uninstalling breakpoints
  class Breakpoint

    INT3 = 0xCC ## obviously x86 specific debugger here

    attr_accessor :orig, :bpid, :bppid, :function
    attr_reader :addr

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
  def initialize(pid, opts) ## Debuggertux Class
    if p.to_i.kind_of? Fixnum
      @pid = pid.to_i
    else
      raise "Provide a PID"
    end

    @opts = opts

    default_opts(opts)
    @installed = false
    @attached = false

    @mapped_regions = Hash.new

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
      if f =~ rx and x.to_i != Process.pid.to_i
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

  ## This has not been fully tested yet
  def set_options(option)
    r = Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::SETOPTIONS, @pid, 0, option)
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

  ## This method returns a hash of mapped regions
  ## The hash is also stored as @mapped_regions
  ## key = Start address of region
  ## value = Size of the region
  def mapped
      if @mapped_regions
        @mapped_regions.clear
      end
      File.read("/proc/#{pid}/maps").each_line do |l|
        s,e = l.split('-')
        e = e.split(' ').first
        sz = e.to_i(16) - s.to_i(16)
        @mapped_regions.store(s.to_i(16), sz)
      end
  end

  ## Not pretty but it works
  def get_mapping_name(val)
    File.read("/proc/#{pid}/maps").each_line do |l|
        base = l.split('-').first
        max = l[0,17].split('-',2)[1]
        if base.to_i(16) <= val && val <= max.to_i(16)
            return l.split(' ').last
        end
    end
    nil
  end

  ## This method parses the proc file system and
  ## saves a hash containing all currently mapped
  ## shared objects. It is accessible as @shared_objects
  def self.shared_libraries(p)
      if @shared_objects
        @shared_objects.clear
      else
        @shared_objects = Hash.new
      end

      File.read("/proc/#{p}/maps").each_line do |l|
          if l =~ /[a-zA-Z0-9].so/ && l =~ /xp /
              lib = l.split(' ', 6)
              sa = l.split('-', 0)

              if lib[5] =~ /vdso/
                next
              end

              lib = lib[5].strip
              lib.gsub!(/[\s\n]+/, "")
              @shared_objects.store(sa[0], lib)
            end
        end
    return @shared_objects
  end

  ## Search a specific page for a value
  ## Should be used by most of the search_* methods
  def search_page(base, max, val)
    loc = Array.new

    while base.to_i < max.to_i
        r = Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::PEEK_TEXT, @pid, base, 0)
        if r == val
            loc.push(base)
        end
        base += 1
    end

    loc
  end

  def search_heap(val)
    loc = Array.new
    File.read("/proc/#{pid}/maps").each_line do |l|
      if l =~ /\[heap\]/
        s,e = l.split('-')
        e = e.split(' ').first
        s = s.to_i(16)
        e = e.to_i(16)
        sz = e - s
        max = s + sz
        loc = search_page(s, max, val)
      end
    end
    loc
  end

  ## Search all mapped regions for a value
  def search_process(val)
    loc = Array.new
    self.mapped
    @mapped_regions.each_pair do |k,v|
        if k == 0 or v == 0
            next
        end
        max = k+v
        loc = search_page(k, max, val)
    end
    loc
  end

  def continue
    on_continue
    Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::CONTINUE, @pid, 0, 0)
  end

  def detach
    on_detach
    Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::DETACH, @pid, 0, 0)
  end

  def single_step
	on_single_step
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

  def wexitstatus(status)
    (((status) & 0xff00) >> 8)
  end

  def wtermsig(status)
    ((status) & 0x7f)
  end

  ## This wait must be smart, it has to wait for a signal
  ## when SIGTRAP is received we need to see if one of our
  ## breakpoints has fired. If it has then execute the block
  ## originally stored with it. If its a different signal,
  ## then process it accordingly and move on
  def wait(opts = 0)
    r, status = Ragweed::Wraptux::waitpid(@pid, opts)
    wstatus = wtermsig(status)
    signal = wexitstatus(status)
    event_code = (status >> 16)
    found = false

    if r[0] != -1    ## Check the ret
      case ## FIXME - I need better logic (use Signal module)
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
        self.on_sigtrap
        r = self.get_registers
        eip = r[:eip]
        eip -= 1
        case
          when @breakpoints.has_key?(eip)
            found = true
            self.on_breakpoint
            self.continue
          when event_code == Ragweed::Wraptux::Ptrace::EventCodes::FORK
                p = FFI::MemoryPointer.new(:int, 1)
                Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::GETEVENTMSG, @pid, 0, p.to_i)
                ## Fix up the PID in each breakpoint
                if (1..65535) === p.get_int32(0) && @opts[:fork] == true
                    @breakpoints.each_pair do |k,v|
                        v.each do |b|
                            b.bpid = p[:pid];
                            b.bppid = p[:pid];
                        end
                    end

                    @pid = p[:pid]
                    self.on_fork_child(@pid)
                end
            when event_code == Ragweed::Wraptux::Ptrace::EventCodes::EXEC
            when event_code == Ragweed::Wraptux::Ptrace::EventCodes::CLONE
            when event_code == Ragweed::Wraptux::Ptrace::EventCodes::VFORK
            when event_code == Ragweed::Wraptux::Ptrace::EventCodes::EXIT
                ## Not done yet
          else
            self.continue
        end
      when signal == Ragweed::Wraptux::Signal::SIGCHLD
        self.on_sigchild
      when signal == Ragweed::Wraptux::Signal::SIGTERM
        self.on_sigterm
      when signal == Ragweed::Wraptux::Signal::SIGCONT
        self.continue
      when signal == Ragweed::Wraptux::Signal::SIGSTOP
        self.on_sigstop
        Ragweed::Wraptux::kill(@pid, Ragweed::Wraptux::Signal::SIGCONT)
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
    regs = FFI::MemoryPointer.new(:int, PTRegs.size)
    Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::GETREGS, @pid, 0, regs.to_i)
    return PTRegs.new regs
  end

  ## Sets registers for the given process
  def set_registers(regs)
    Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::SETREGS, @pid, 0, regs.to_ptr.address)
  end

  ## Here we need to do something about the bp
  ## we just hit. We have a block to execute.
  ## Remember if you implement this on your own
  ## make sure to call super, and also realize
  ## EIP won't look correct until this runs
  def on_breakpoint
    r = get_registers
    eip = r[:eip]
    eip -= 1
    ## Call the block associated with the breakpoint
    @breakpoints[eip].call(r, self)

    if @breakpoints[eip].first.installed?
      @breakpoints[eip].first.uninstall
      r[:eip] = eip
      set_registers(r)
      single_step
      ## ptrace peektext returns -1 upon reinstallation of bp without calling
      ## waitpid() if that occurs the breakpoint cannot be reinstalled
      Ragweed::Wraptux::waitpid(@pid, 0)
      @breakpoints[eip].first.install
    end
  end

  def print_registers
    regs = get_registers
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
  end

  def on_illegalinst
  end

  def on_attach
  end

  def on_detach
  end

  def on_sigchild
  end

  def on_sigterm
  end

  def on_sigtrap
  end

  def on_continue
  end

  def on_sigstop
  end

  def on_signal
  end

  def on_single_step
  end

  def on_fork_child(pid)
  end

  def on_segv
  end

  def default_opts(opts)
    @opts = @opts.merge(opts)
  end
end
