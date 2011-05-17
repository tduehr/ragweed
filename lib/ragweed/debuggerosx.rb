require ::File.join(::File.dirname(__FILE__),'wraposx')

module Ragweed; end

# Debugger class for Mac OS X
# You can use this class in 2 ways:
#
# (1) You can create instances of Debuggerosx and use them to set and handle
#     breakpoints.
#
# (2) If you want to do more advanced event handling, you can subclass from
#     debugger and define your own on_whatever events. If you handle an event
#     that Debuggerosx already handles, call "super", too.
class Ragweed::Debuggerosx
  include Ragweed

  attr_reader :pid
  attr_reader :status
  attr_reader :task
  attr_reader :exited
  attr_accessor :breakpoints

  class Breakpoint
    #    include Ragweed::Wraposx
    INT3 = 0xCC
    attr_accessor :orig
    attr_accessor :bpid
    attr_reader :addr
    attr_accessor :function

    # bp: parent for method_missing calls
    # ip: insertion point
    # callable: lambda to be called when breakpoint is hit
    # name: name of breakpoint
    def initialize(bp, ip, callable, name = "")
      @@bpid ||= 0
      @bp = bp
      @function = name
      @addr = ip
      @callable = callable
      @bpid = (@@bpid += 1)
      @installed = false
    end

    # Install this breakpoint.
    def install
      Ragweed::Wraposx::task_suspend(@bp.task)
      @bp.hook if not @bp.hooked?
      Ragweed::Wraposx::vm_protect(@bp.task,@addr,1,false,Ragweed::Wraposx::Vm::Prot::ALL)
      @orig = Ragweed::Wraposx::vm_read(@bp.task,@addr,1)
      if(@orig != INT3)
        Ragweed::Wraposx::vm_write(@bp.task,@addr, [INT3].pack('C'))
      end
      @installed = true
      Ragweed::Wraposx::task_resume(@bp.task)
    end

    # Uninstall this breakpoint.
    def uninstall
      Ragweed::Wraposx::task_suspend(@bp.task)
      if(@orig != INT3)
        Ragweed::Wraposx::vm_write(@bp.task, @addr, @orig)
      end
      @installed = false
      Ragweed::Wraposx::task_resume(@bp.task)
    end

    def installed?; @installed; end
    def call(*args); @callable.call(*args) if @callable != nil; end
    def method_missing(meth, *args); @bp.send(meth, *args); end
  end

  #init object
  #p: pid of process to be debugged
  #opts: default options for automatically doing things (attach, install, and hook)
  def initialize(p,opts={})
    if p.kind_of? Numeric
      @pid = p
    else
      #coming soon: find process by name
      raise "Provide a PID"
    end
    @opts = opts
    default_opts(opts)

    @installed = false
    @attached = false
    @hooked = false
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

  #loop calls to wait
  #times: number of times to loop
  #       if nil this will loop until @exited is set
  def loop(times=nil)
    if times.kind_of? Numeric
      times.times do
        self.wait
      end
    elsif times.nil?
      self.wait while not @exited
    end
  end

  # wait for process and run callback on return then continue child
  # FIXME - need to do signal handling better (loop through threads only for breakpoints and stepping)
  # opts: option flags to waitpid(2)
  #
  # returns an array containing the pid of the stopped or terminated child and the status of that child
  # r[0]: pid of stopped/terminated child or 0 if Ragweed::Wraposx::Wait:NOHANG was passed and there was nothing to report
  # r[1]: staus of child or 0 if Ragweed::Wraposx::Wait:NOHANG was passed and there was nothing to report
  def wait(opts = 0)
    r = Ragweed::Wraposx::waitpid(@pid,opts)
    status = r[1]
    wstatus = status & 0x7f
    signal = status >> 8
    found = false
    if r[0] != 0 #r[0] == 0 iff wait had nothing to report and NOHANG option was passed
      case
      when wstatus == 0 #WIFEXITED
        @exited = true
        try(:on_exit, signal)
      when wstatus != 0x7f #WIFSIGNALED
        @exited = false
        try(:on_signaled, wstatus)
      when signal != 0x13 #WIFSTOPPED
        self.threads.each do |t|
          if @breakpoints.has_key?(self.get_registers(t).eip-1)
            found = true
            try(:on_breakpoint, t)
          end
        end
        if not found # no breakpoint so iterate through Signal constants to find the current SIG
          Signal.list.each do |sig, val|
            try("on_sig#{ sig.downcase }".intern) if signal == val
          end
        end
        try(:on_stop, signal)
        begin
          self.continue
        rescue Errno::EBUSY
          # Yes this happens and it's wierd
          # Not sure it should happen
          if $DEBUG
            puts 'unable to self.continue'
            puts self.get_registers
          end
        retry
        end
      when signal == 0x13 #WIFCONTINUED
        try(:on_continue)
      else
        raise "Unknown signal '#{signal}' recieved: This should not happen - ever."
      end
    end
    return r
  end

  # these event functions are stubs. Implementations should override these
  def on_attach
  end

  def on_detach
  end

  def on_single_step
    #puts Ragweed::Wraposx::ThreadInfo.get(thread).inspect
  end

  def on_exit(status)
    @exited = true
  end

  def on_signal(signal)
    @exited = true
  end

  def on_stop(signal)
  end

  def on_continue
  end

  # installs all breakpoints into child process
  # add breakpoints to install via breakpoint_set
  def install_bps
    self.hook if not @hooked
    @breakpoints.each do |k,v|
      v.install
    end
    @installed = true
  end

  # removes all breakpoints from child process
  def uninstall_bps
    @breakpoints.each do |k,v|
      v.uninstall
    end
    @installed = false
  end

  # attach to @pid for debugging
  # opts is a hash for automatically firing other functions as an overide for @opts
  # returns 0 on no error
  def attach(opts=@opts)
    r = Ragweed::Wraposx::ptrace(Ragweed::Wraposx::Ptrace::ATTACH,@pid,0,0)
    # Ragweed::Wraposx::ptrace(Ragweed::Wraposx::Ptrace::CONTINUE,@pid,1,0)
    @attached = true
    on_attach
    self.hook(opts) if (opts[:hook] and not @hooked)
    self.install_bps if (opts[:install] and not @installed)
    return r
  end

  # remove breakpoints and release child
  # opts is a hash for automatically firing other functions as an overide for @opts
  # returns 0 on no error
  def detach(opts=@opts)
    self.uninstall_bps if @installed
    r = Ragweed::Wraposx::ptrace(Ragweed::Wraposx::Ptrace::DETACH,@pid,0,Ragweed::Wraposx::Wait::UNTRACED)
    @attached = false
    on_detach
    self.unhook(opts) if opts[:hook] and @hooked
    return r
  end

  # get task port for @pid and store in @task so mach calls can be made
  # opts is a hash for automatically firing other functions as an overide for @opts
  # returns the task port for @pid
  def hook(opts=@opts)
    @task = Ragweed::Wraposx::task_for_pid(@pid)
    @hooked = true
    self.attach(opts) if opts[:attach] and not @attached
    return @task
  end

  # theoretically to close the task port but,
  # no way to close the port has yet been found.
  # This function currently does little/nothing.
  def unhook(opts=@opts)
    self.detach(opts) if opts[:attach] and @attached
    self.unintsall_bps if opts[:install] and @installed
  end

  # resumes thread that has been suspended via thread_suspend
  # thread: thread id of thread to be resumed
  def resume(thread = nil)
    thread = (thread or self.threads.first)
    Ragweed::Wraposx::thread_resume(thread)
  end

  # suspends thread
  # thread: thread id of thread to be suspended
  def suspend(thread = nil)
    thread = (thread or self.threads.first)
    Ragweed::Wraposx::thread_suspend(thread)
  end

  # sends a signal to process with id @pid
  # sig: signal to be sent to process @pid
  def kill(sig = 0)
    Ragweed::Wraposx::kill(@pid,sig)
  end

  # adds a breakpoint and callable block to be installed into child process
  # ip: address of insertion point
  # callable: object to receive call() when this breakpoint is hit
  def breakpoint_set(ip, name="", callable=nil, &block)
    if not callable and block_given?
      callable = block
    end
    @breakpoints[ip] << Breakpoint.new(self, ip, callable, name)
  end

  # removes breakpoint from child process
  # ip: insertion point of breakpoints to be removed
  # bpid: id of breakpoint to be removed
  def breakpoint_clear(ip, bpid=nil)
    if not bpid
      @breakpoints[ip].uninstall
      @breakpoints.delete ip
    else
      found = nil
      @breakpoints[ip].each_with_index do |bp, i|
        if bp.bpid == bpid
          found = i
          if bp.orig != Breakpoint::INT3
            if @breakpoints[ip][i+1]
              @breakpoints[ip][i + 1].orig = bp.orig
            else
              bp.uninstall
            end
          end
        end
      end
      raise "couldn't find #{ ip }" if not found
      @breakpoints[ip].delete_at(found) if found
    end
  end

  # default method for breakpoint handling
  # thread: id of the thread stopped at a breakpoint
  def on_breakpoint(thread)
    r = self.get_registers(thread)
    #rewind eip to correct position
    r.eip -= 1
    #don't use r.eip since it may be changed by breakpoint callback
    eip = r.eip
    #clear stuff set by INT3
    #r.esp -=4
    #r.ebp = r.esp
    #fire callback
    @breakpoints[eip].call(thread, r, self)
    if @breakpoints[eip].first.installed?
      #uninstall breakpoint to continue past it
      @breakpoints[eip].first.uninstall
      #set trap flag so we don't go too far before reinserting breakpoint
      r.eflags |= Ragweed::Wraposx::EFlags::TRAP
      #set registers to commit eip and eflags changes
      self.set_registers(thread, r)

      #step once
      self.stepp

      # now we wait() to prevent a race condition that'll SIGBUS us
      # Yup, a race condition where the child may not complete a single 
      # instruction before the parent completes many
      Ragweed::Wraposx::waitpid(@pid,0)

      #reset breakpoint
      @breakpoints[eip].first.install
    end
  end

  # returns an array of the thread ids of the child process
  def threads
    self.hook if not @hooked
    Ragweed::Wraposx::task_threads(@task)
  end

  # decrement our tasks suspend count
  def resume_task
    Ragweed::Wraposx::task_resume(@task)
  end

  # increment our tasks suspend count
  def suspend_task
    Ragweed::Wraposx::task_suspend(@task)
  end

  # returns a Ragweed::Wraposx::ThreadContext object containing the register states
  # thread: thread to get the register state of
  def get_registers(thread=nil)
    thread = (thread or self.threads.first)
    Ragweed::Wraposx.thread_get_state(thread, Ragweed::Wraposx::ThreadContext::X86_THREAD_STATE)
  end

  # sets the register state of a thread
  # thread: thread id to set registers for
  # regs: Ragweed::Wraposx::ThreadContext object containing the new register state for the thread
  def set_registers(thread, regs)
    # XXX - needs updated conditions
    # raise "Must supply registers and thread to set" if (not (thread and regs) or not thread.kind_of? Numeric or not regs.kind_of? Ragweed::Wraposx::ThreadContext)
    Ragweed::Wraposx.thread_set_state(thread, regs.class::FLAVOR, regs)
  end

  # continue stopped child process.
  # addr: address from which to continue child. defaults to current position.
  # data: signal to be sent to child. defaults to no signal.
  def continue(addr = 1, data = 0)
    Ragweed::Wraposx::ptrace(Ragweed::Wraposx::Ptrace::CONTINUE,@pid,addr,data)
  end

  # Do not use this function unless you know what you're doing!
  # It causes a kernel panic in some situations (fine if the trap flag is set in theory)
  # same arguments as Debugerosx#continue
  # single steps the child process
  def stepp(addr = 1, data = 0)
    Ragweed::Wraposx::ptrace(Ragweed::Wraposx::Ptrace::STEP,@pid,addr,data)
  end

  # sends a signal to a thread of the child's
  # this option to ptrace is undocumented in OS X, usage pulled from gdb and googling
  # thread: id of thread to which a signal is to be sent
  # sig: signal to be sent to child's thread
  def thread_update(thread = nil, sig = 0)
    thread = thread or self.threads.first
    Ragweed::Wraposx::ptrace(Ragweed::Wraposx::Ptrace::THUPDATE,@pid,thread,sig)
  end

  def hooked?; @hooked; end
  def attached?; @attached; end
  def installed?; @installed; end

  def region_info(addr, flavor = :basic)
    flav = case flavor
    when :basic
      Ragweed::Wraposx::RegionBasicInfo::FLAVOR

    # Extended and Top info flavors are included in case Apple re implements them
    when :extended
      Ragweed::Wraposx::RegionExtendedInfo::FLAVOR
    when :top
      Ragweed::Wraposx::RegionTopInfo::FLAVOR
    when Integer
      flavor
    else
      warn "Unknown flavor requested. Returning RegionBasicInfo."
      Ragweed::Wraposx::RegionBasicInfo::FLAVOR
    end
    
    if Ragweed::Wraposx.respond_to? :vm_region_64
      Ragweed::Wraposx.vm_region_64(@task, addr, flav)
    else
      Ragweed::Wraposx.vm_region(@task, addr, flav)
    end
  end

  # XXX watch this space for an object to hold this information
  # Return a range via mapping name
  def get_mapping_by_name name, exact = true
    ret = []
    IO.popen("vmmap -interleaved #{@pid}") do |pipe|
      pipe.each_line do |line|
        next if pipe.lineno < 5
        break if line == "==== Legend\n"
        rtype, saddr, eaddr, sz, perms, sm, purpose =
          line.scan(/^([[:graph:]]+(?:\s[[:graph:]]+)?)\s+([[:xdigit:]]+)-([[:xdigit:]]+)\s+\[\s+([[:digit:]]+[A-Z])\s*\]\s+([-rwx\/]+)\s+SM=(COW|PRV|NUL|ALI|SHM|ZER|S\/A)\s+(.*)$/).
            first
        if exact && (rtype == name || purpose == name)
          ret << [saddr, eaddr].map{|x| x.to_i(16)}
        elsif rtype.match(name) || purpose.match(name)
          ret << [saddr, eaddr].map{|x| x.to_i(16)}
        end
      end
    end
    ret
  end
  
  def get_stack_ranges
    get_mapping_by_name "Stack", false
  end
  
  def get_heap_ranges
    get_mapping_by_name "MALLOC", false
  end

  private

  # sets instance automagic options to sane(ish) defaults when not given
  # FIXME - I should use Hash#merge!
  def default_opts(opts)
    @opts[:hook] = opts[:hook] != nil ? opts[:hook] : true
    @opts[:attach] = opts[:attach] != nil ? opts[:attach] : false
    @opts[:install] = opts[:install] != nil ? opts[:install] : false
  end
end
