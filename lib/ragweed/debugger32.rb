require ::File.join(::File.dirname(__FILE__),'wrap32')

# I am not particularly proud of this code, which I basically debugged
# into existence, but it does work.

# Debugger class for win32
# You can use this class in 2 ways:
#
# (1) You can create instances of Debugger and use them to set and handle
#     breakpoints.
#
# (2) If you want to do more advanced event handling, you can subclass from
#     debugger and define your own on_whatever events. If you handle an event
#     that Debugger already handles, call "super", too.
class Ragweed::Debugger32
  include Ragweed

  # Breakpoint class. Handles the actual setting,
  # removal and triggers for breakpoints.
  # no user servicable parts.
  class Breakpoint
    INT3 = 0xCC
    attr_accessor :orig
    attr_accessor :bpid
    attr_accessor :bps
    attr_accessor :deferred
    attr_accessor :addr

    def initialize(process, ip, status, callable)
      @@bpid ||= 0
      @process = process
      @addr = ip
      @callable = callable
      @bpid = (@@bpid += 1)
      @deferred = status
      @orig = 0
    end

    def addr; @addr; end
    
    def install
        if @addr == 0
          return
        end
        o = @process.read8(@addr)

        if(orig != INT3)
          @orig = o
          @process.write8(@addr, INT3) 
          Ragweed::Wrap32::flush_instruction_cache(@process.handle)
        end
    end

    def deferred_install(h, base)
        @addr = @process.get_deferred_proc_remote(@addr, h, base)
        self.install
        return @addr
    end

    def uninstall
      if(@orig != INT3)
        @process.write8(@addr, @orig) 
        Ragweed::Wrap32::flush_instruction_cache(@process.handle)
      end
    end

    def call(*args); @callable.call(*args); end    
    def method_missing(meth, *args); @bp.send(meth, *args); end
  end

  # Get a handle to the process so you can mess with it.
  def process; @p; end
  
  # This is how you normally create a debug instance: with a regex
  # on the image name of the process.
  #    d = Debugger.find_by_regex /notepad/i
  def self.find_by_regex(rx)
    Ragweed::Wrap32::all_processes do |p|
      if p.szExeFile =~ rx
        return self.new(p.th32ProcessID)
      end
    end
    nil
  end
    
  # If you want to get one by hand, and not by Debugger#find_by_regex,
  # pass this either a PID or a Process object.
  def initialize(p)
    # grab debug privilege at least once.
    @@token ||= Ragweed::Wrap32::ProcessToken.new.grant("seDebugPrivilege")

    p = Process.new(p) if p.kind_of? Numeric
    @p = p
    @steppers = []
    @handled = Ragweed::Wrap32::ContinueCodes::UNHANDLED
    @first = true
    @attached = false
    @def_status = true

    ## For setting breakpoints: inject a thread to do GetProcAddress, cache
    ## the result. Sometimes we are forced fed deferred breakpoints here
    ## This is better documented in wrap32/process.rb but be aware of it!
    @resolve = Hash.new do |h, k|

      ## This is usually 'Module!Function' or 'Module!0x1234'
      if k.kind_of? String
        if @p.is_breakpoint_deferred(k) == true
            @def_status = true
            ip = k
        else
            @def_status = false
            ip = @p.get_proc_remote(k)
        end
      else
        ip = k
      end

      ## If we cant immediately set the breakpoint
      ## mark it as deferred and wait till later
      ## Sometimes *_proc_remote() will return the
      ## name indicating failure (just in case)
      if ip == 0 or ip == 0xFFFFFFFF or ip.kind_of? String
        @def_status = true
      else
        @def_status = false
      end
 
      h[k] = ip
    end

    ## The magic initializer here just makes sure the Hash always
    ## contains arrays with convenience methods.
    ## The breakpoints are keyed by breakpoint location. In the
    ## case of a deferred breakpoint, the key will be a String
    ## containing the original Module!Location breakpoint
    @breakpoints = Hash.new do |h, k|
      bps = Array.new

      def bps.call(*args); each { |bp| bp.call(*args) }; end

      def bps.install
        each do |bp|
            if bp.deferred == false
              bp.install
            end
        end
      end

      def bps.deferred_install(h, base)
        a = nil
        each do |bp|
            a = bp.deferred_install(h, base)
        end
        return a
      end

      def bps.uninstall; each {|bp| bp.uninstall}; end 

      h[k] = bps
    end
  end

  # single-step the thread (by TID). "callable" is something that honors
  # .call, like a Proc. In a dubious design decision: the "handle" to the
  # single stepper is the Proc object itself. See Debugger#on_breakpoint
  # for an example of how to use this.
  def step(tid, callable)
    if @steppers.empty?
      Ragweed::Wrap32::open_thread(tid) do |h|
        ctx = Ragweed::Wrap32::ThreadContext.get(h)
        ctx.single_step(true)
        ctx.set(h)
      end
    end
    @steppers << callable    
  end

  # turn off single-stepping for one callable (you can have more than one
  # at a time). In other words, when you pass a Proc to Debugger#step, save
  # it somewhere, and later pass it to "unstep" to turn it off. 
  def unstep(tid, callable)
    @steppers = @steppers.reject {|x| x == callable}
    if @steppers.empty?
      Ragweed::Wrap32::open_thread(tid) do |h|
        ctx = Ragweed::Wrap32::ThreadContext.get(h)
        ctx.single_step(false)
        ctx.set(h)
      end
    end
  end

  # convenience: either from a TID or a BreakpointEvent, get the thread context.
  def context(tid_or_event)
    if not tid_or_event.kind_of? Numeric
      tid = tid_or_event.tid
    else
      tid = tid_or_event
    end
    Ragweed::Wrap32::open_thread(tid) {|h| Ragweed::Wrap32::ThreadContext.get(h)}
  end

  # set a breakpoint given an address, which can also be a string in the form
  # "module!function", as in, "user32!SendMessageW". Be aware that the symbol
  # lookup takes place in an injected thread; it's safer to use literal addresses.
  #
  # to handle the breakpoint, pass a block to this method, which will be called
  # when the breakpoint hits.
  #
  # breakpoints are always re-set after firing. If you don't want them to be
  # re-set, unset them manually.
  #
  # returns a numeric id that can be used to clear the breakpoint.
  def breakpoint_set(ip, callable=nil, &block)
    if not callable and block_given?
      callable = block
    end
    ip = @resolve[ip]
    @breakpoints[ip] << Breakpoint.new(@p, ip, @def_status, callable)
  end

  # clear a breakpoint given an id, or clear all breakpoints associated with
  # an address.  
  def breakpoint_clear(ip, bpid=nil)
    ip = @resolve[ip]
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
  
  # handle a breakpoint event:
  # call handlers for the breakpoint, step past and reset it.
  def on_breakpoint(ev)
    if @first

      # DbgUiRemoteInjectWhatever actually injects a thread into the
      # target process, which explicitly issues an INT3. We never care
      # about this breakpoint right now.
      @first = false
    else
      ctx = context(ev)
      eip = ev.exception_address
      
      # call handlers, then clear the breakpoint so we can execute the
      # real instruction.
      @breakpoints[eip].first.uninstall
      @breakpoints[eip].call(ev, ctx)

      # single step past the instruction...
      step(ev.tid, (onestep = lambda do |ev, ctx|
        if ev.exception_address != eip

          # ... then re-install the breakpoint ...
          if not @breakpoints[eip].empty?
            @breakpoints[eip].first.install
          end

          # ... and stop single-stepping.
          unstep(ev.tid, onestep)
        end
      end))

      # put execution back where it's supposed to be...
      Ragweed::Wrap32::open_thread(ev.tid) do |h|
        ctx = context(ev)
        ctx.eip = eip # eip was ev.exception_address
        ctx.set(h)
      end
    end
  
    # tell the target to stop handling this event
    @handled = Ragweed::Wrap32::ContinueCodes::CONTINUE
  end

  def on_load_dll(ev)
    name = Ragweed::Wrap32::get_mapped_filename(@p.handle, ev.dll_base, 256)
    ## TODO - hash DLLs instead of this garbage
    name.gsub!(/\s/, '')
    name.gsub!(/\0/, '')

    @breakpoints.each_pair do |k,v|

        if v[0].nil?
            ## This happens sometimes, but why? i smell a bug
            return
        end

        addr = v[0].addr

        if !addr.kind_of?String
            next
        end

        m,f = addr.split('!')

        if name =~ /#{m}/i
            deferred = v[0].deferred

            if deferred == true
                v[0].deferred = false
            end

            new_addr = v.deferred_install(ev.file_handle, ev.dll_base)

            if !new_addr.nil?
                @breakpoints.delete(k)
                k = new_addr
                @breakpoints[k] = v
            end
        end
    end
  end

  # handle a single-step event  
  def on_single_step(ev)
    ctx = context(ev)
    Ragweed::Wrap32::open_thread(ev.tid) do |h|
      # re-enable the trap flag before our handler,
      # which may choose to disable it.
      ctx.single_step(true)
      ctx.set(h)
    end
    
    @steppers.each {|s| s.call(ev, ctx)}
        
    @handled = Ragweed::Wrap32::ContinueCodes::CONTINUE
  end

  # this is sort of insane but most of my programs are just
  # debug loops, so if you don't do this, they just hang when
  # the target closes.
  def on_exit_process(ev)
    exit(1)
  end

  # Read through me to see all the random events you can hook in
  # a subclass. 
  # 
  # call me directly if you want to handle multiple debugger instances,
  # i guess. 
  def wait
    self.attach() if not @attached

    ev = Ragweed::Wrap32::wait_for_debug_event
    return if not ev
    case ev.code
    when Ragweed::Wrap32::DebugCodes::CREATE_PROCESS
      try(:on_create_process, ev)
    when Ragweed::Wrap32::DebugCodes::CREATE_THREAD
      try(:on_create_thread, ev)
    when Ragweed::Wrap32::DebugCodes::EXIT_PROCESS
      try(:on_exit_process, ev)
    when Ragweed::Wrap32::DebugCodes::EXIT_THREAD
      try(:on_exit_thread, ev)
    when Ragweed::Wrap32::DebugCodes::LOAD_DLL
      try(:on_load_dll, ev)
    when Ragweed::Wrap32::DebugCodes::OUTPUT_DEBUG_STRING
      try(:on_output_debug_string, ev)
    when Ragweed::Wrap32::DebugCodes::RIP
      try(:on_rip, ev)
    when Ragweed::Wrap32::DebugCodes::UNLOAD_DLL
      try(:on_unload_dll, ev)
    when Ragweed::Wrap32::DebugCodes::EXCEPTION
      case ev.exception_code
      when Ragweed::Wrap32::ExceptionCodes::ACCESS_VIOLATION
        try(:on_access_violation, ev)
      when Ragweed::Wrap32::ExceptionCodes::BREAKPOINT 
        try(:on_breakpoint, ev)
      when Ragweed::Wrap32::ExceptionCodes::ALIGNMENT  
        try(:on_alignment, ev)
      when Ragweed::Wrap32::ExceptionCodes::SINGLE_STEP 
        try(:on_single_step, ev)
      when Ragweed::Wrap32::ExceptionCodes::BOUNDS 
        try(:on_bounds, ev)
      when Ragweed::Wrap32::ExceptionCodes::DIVIDE_BY_ZERO 
        try(:on_divide_by_zero, ev)
      when Ragweed::Wrap32::ExceptionCodes::INT_OVERFLOW 
        try(:on_int_overflow, ev)
      when Ragweed::Wrap32::ExceptionCodes::INVALID_HANDLE 
        try(:on_invalid_handle, ev)
      when Ragweed::Wrap32::ExceptionCodes::PRIV_INSTRUCTION 
        try(:on_priv_instruction, ev)
      when Ragweed::Wrap32::ExceptionCodes::STACK_OVERFLOW 
        try(:on_stack_overflow, ev)
      when Ragweed::Wrap32::ExceptionCodes::INVALID_DISPOSITION 
        try(:on_invalid_disposition, ev)
      end
    end

    Ragweed::Wrap32::continue_debug_event(ev.pid, ev.tid, @handled)
    @handled = Ragweed::Wrap32::ContinueCodes::UNHANDLED
  end

  # debug loop
  def loop
    while true
      wait
    end
  end
  
  # this is called implicitly by Debugger#wait.
  # Attaches to the child process for debugging
  def attach
    Ragweed::Wrap32::debug_active_process(@p.pid)
    Ragweed::Wrap32::debug_set_process_kill_on_exit
    @attached = true
    @breakpoints.each do |k, v|
      v.install
    end
  end

  # let go of the target.
  def release
    Ragweed::Wrap32::debug_active_process_stop(@p.pid)
    @attached = false
    @breakpoints.each do |k, v|
      v.uninstall
    end
  end
end
