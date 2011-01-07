require ::File.join(::File.dirname(__FILE__),'wraptux')

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
  attr_reader :pid, :status, :exited, :signal
  attr_accessor :breakpoints, :mapped_regions

  ## Class to handle installing/uninstalling breakpoints
  class Breakpoint

    INT3 = 0xCC

    attr_accessor :orig, :bppid, :function, :installed
    attr_reader :addr

    ## ip: insertion point
    ## callable: lambda to be called when breakpoint is hit
    ## p: process ID
    ## name: name of breakpoint
    def initialize(ip, callable, p, name = "")
	  @bppid = p
      @function = name
      @addr = ip
      @callable = callable
      @installed = false
      @exited = false
      @orig = 0
    end

    def install
      @orig = Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::PEEK_TEXT, @bppid, @addr, 0)
      if @orig != -1
        n = (@orig & ~0xff) | INT3;
        Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::POKE_TEXT, @bppid, @addr, n)
        @installed = true
      else
        @installed = false
      end
    end

    def uninstall
      if @orig != INT3
        a = Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::POKE_TEXT, @bppid, @addr, @orig)
        @installed = false
      end
    end

    def installed?; @installed; end
    def call(*args); @callable.call(*args) if @callable != nil; end
  end

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
    @breakpoints = Hash.new
    @opts.each { |k, v| try(k) if v }
  end

  def self.find_by_regex(rx)
    a = Dir.entries("/proc/")
    a.delete_if { |x| x == '.' }
    a.delete_if { |x| x == '..' }
    a.delete_if { |x| x =~ /[a-z]/i }
    
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
      @mapped_regions.clear if @mapped_regions

      File.read("/proc/#{pid}/maps").each_line do |l|
        s,e = l.split('-')
        e = e.split(' ').first
        sz = e.to_i(16) - s.to_i(16)
        @mapped_regions.store(s.to_i(16), sz)
      end
  end

  ## Return a name for a range if possible
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

  ## Return a range via mapping name
  def get_mapping_by_name(name)
    File.read("/proc/#{pid}/maps").each_line do |l|
        n = l.split(' ').last
        if n == name
            base = l.split('-').first
            max = l[0,17].split('-',2)[1]
            return [base, max]
        end
    end
    nil
  end

  ## Helper method for retrieving stack range
  def get_stack_range
    l = get_mapping_by_name("[stack]")
    return [0,0] if l == nil; else return l
  end

  ## Helper method for retrieving heap range
  def get_heap_range
    l = get_mapping_by_name("[heap]")
    return [0,0] if l == nil; else return l
  end

  ## Parse procfs and create a hash containing
  ## a listing of each mapped shared object
  def self.shared_libraries(p)

      raise "pid is 0" if p.to_i == 0

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

  ## Search the heap for a value
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
        loc.concat(search_page(k, max, val))
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
    @breakpoints.each_key { |k| if k == ip then return end }
    bp = Breakpoint.new(ip, callable, @pid, name)
    @breakpoints[ip] = bp
  end

  ## Remove a breakpoint by ip
  def breakpoint_clear(ip)
    bp = @breakpoints[ip]
    return nil if bp.nil?
    bp.uninstall
  end

  ## loop for wait()
  ## times: the number of wait calls to make
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
        try(:on_exit)
      when wstatus != 0x7f ##WIFSIGNALED
        @exited = false
        try(:on_signal)
      when signal == Ragweed::Wraptux::Signal::SIGINT
        try(:on_sigint)
        self.continue
      when signal == Ragweed::Wraptux::Signal::SIGSEGV
        try(:on_segv)
      when signal == Ragweed::Wraptux::Signal::SIGILL
        try(:on_illegal_instruction)
      when signal == Ragweed::Wraptux::Signal::SIGIOT
        try(:on_iot_trap)
        self.continue
      when signal == Ragweed::Wraptux::Signal::SIGTRAP
        try(:on_sigtrap)
        r = self.get_registers
        eip = r.eip
        eip -= 1
        case
          when @breakpoints.has_key?(eip)
            found = true
            try(:on_breakpoint)
            self.continue
          when event_code == Ragweed::Wraptux::Ptrace::EventCodes::FORK
                p = FFI::MemoryPointer.new(:int, 1)
                Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::GETEVENTMSG, @pid, 0, p.to_i)
                ## Fix up the PID in each breakpoint
                if (1..65535) === p.get_int32(0) && @opts[:fork] == true
                    @breakpoints.each_pair do |k,v|
                        v.each do |b|
                            b.bppid = p[:pid]
                        end
                    end

                    @pid = p[:pid]
                    try(:on_fork_child, @pid)
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
        try(:on_sigchild)
      when signal == Ragweed::Wraptux::Signal::SIGTERM
        try(:on_sigterm)
      when signal == Ragweed::Wraptux::Signal::SIGCONT
        try(:on_continue)
        self.continue
      when signal == Ragweed::Wraptux::Signal::SIGSTOP
        try(:on_sigstop)
        Ragweed::Wraptux::kill(@pid, Ragweed::Wraptux::Signal::SIGCONT)
        self.continue
	  when signal == Ragweed::Wraptux::Signal::SIGWINCH
		self.continue
      else
        raise "Add more signal handlers (##{signal})"
      end
    end
  end

  def self.threads(pid)
	begin
	    a = Dir.entries("/proc/#{pid}/task/")
	rescue
		puts "No such PID: #{pid}"
		return
	end
    a.delete_if { |x| x == '.' }
    a.delete_if { |x| x == '..' }
  end

  def get_registers
    regs = FFI::MemoryPointer.new(Ragweed::Wraptux::PTRegs, 1)
    Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::GETREGS, @pid, 0, regs.to_i)
    return Ragweed::Wraptux::PTRegs.new regs
  end

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
    eip = r.eip
    eip -= 1

    ## Call the block associated with the breakpoint
    @breakpoints[eip].call(r, self)

    ## The block may have called breakpoint_clear
    del = true if !@breakpoints[eip].installed?

    ## Uninstall and single step the bp
    @breakpoints[eip].uninstall
    r.eip = eip
    set_registers(r)
    single_step

    ## ptrace peektext returns -1 upon reinstallation of bp without calling
    ## waitpid() if that occurs the breakpoint cannot be reinstalled
    Ragweed::Wraptux::waitpid(@pid, 0)

    if del == true
        ## The breakpoint block may have called breakpoint_clear
        @breakpoints.delete(eip)
    else
        @breakpoints[eip].install
    end
  end

  def on_attach()              end
  def on_single_step()         end
  def on_continue()            end
  def on_exit()                end
  def on_signal()              end
  def on_sigint()              end
  def on_segv()                end
  def on_illegal_instruction() end
  def on_sigtrap()             end
  def on_fork_child(pid)       end
  def on_sigchild()            end
  def on_sigterm()             end
  def on_sigstop()             end
  def on_iot_trap()            end

  def print_registers
    regs = get_registers
    puts "eip %08x" % regs.eip
    puts "esi %08x" % regs.esi
    puts "edi %08x" % regs.edi
    puts "esp %08x" % regs.esp
    puts "eax %08x" % regs.eax
    puts "ebx %08x" % regs.ebx
    puts "ecx %08x" % regs.ecx
    puts "edx %08x" % regs.edx
  end

  def default_opts(opts)
    @opts = @opts.merge(opts)
  end
end
