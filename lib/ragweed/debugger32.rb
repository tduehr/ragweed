require ::File.join(::File.dirname(__FILE__),'wrap32')

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

  ## Breakpoint class. Handles the actual setting,
  ## removal and triggers for breakpoints.
  ## no user servicable parts.
  class Breakpoint

    INT3 = 0xCC

    attr_accessor :orig, :deferred, :addr

    def initialize(process, ip, def_status, callable)
      @process = process
      @addr = ip
      @callable = callable
      @deferred = def_status
      @orig = 0
    end

    def addr; @addr; end
    
    def install
        if @addr == 0 or @deferred == true
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
  end ## End Breakpoint class

  ## Get a handle to the process so you can mess with it.
  def process; @p; end
  
  def self.find_by_regex(rx)
    Ragweed::Wrap32::all_processes do |p|
      if p.szExeFile =~ rx
        return self.new(p.th32ProcessID)
      end
    end
    nil
  end

  def initialize(p)
    ## grab debug privilege at least once
    @@token ||= Ragweed::Wrap32::ProcessToken.new.grant('seDebugPrivilege')

    p = Process.new(p) if p.kind_of? Numeric
    @p = p
    @steppers = []
    @handled = Ragweed::Wrap32::ContinueCodes::UNHANDLED
    @attached = false

    ## breakpoints is a hash with a key being the breakpoint
    ## addr and the value being a Breakpoint class
    @breakpoints = Hash.new

    ## We want to ignore ntdll!DbgBreakPoint 
    @ntdll_dbg_break_point = @p.get_proc_remote('ntdll!DbgBreakPoint')
  end

  ## single-step the thread (by TID). "callable" is something that honors
  ## .call, like a Proc. In a dubious design decision: the "handle" to the
  ## single stepper is the Proc object itself. See Debugger#on_breakpoint
  ## for an example of how to use this.
  def step(tid, callable)
    if @steppers.empty?
      Ragweed::Wrap32::open_thread(tid) do |h|
        ctx = Ragweed::Wrap32::get_thread_context(h)
        ctx.single_step(true)
        Ragweed::Wrap32::set_thread_context(h, ctx)
      end
    end
    @steppers << callable    
  end

  ## turn off single-stepping for one callable (you can have more than one
  ## at a time). In other words, when you pass a Proc to Debugger#step, save
  ## it somewhere, and later pass it to "unstep" to turn it off. 
  def unstep(tid, callable)
    @steppers = @steppers.reject {|x| x == callable}
    if @steppers.empty?
      Ragweed::Wrap32::open_thread(tid) do |h|
        ctx = Ragweed::Wrap32::get_thread_context(h)
        ctx.single_step(false)
        Ragweed::Wrap32::set_thread_context(h, ctx)
      end
    end
  end

  ## convenience: either from a TID or a BreakpointEvent, get the thread context.
  def context(tid_or_event)
    if not tid_or_event.kind_of? Numeric
      tid = tid_or_event.tid
    else
      tid = tid_or_event
    end
    Ragweed::Wrap32::open_thread(tid) { |h| Ragweed::Wrap32::get_thread_context(h) }
  end

  ## set a breakpoint given an address, which can also be a string in the form
  ## "module!function", as in, "user32!SendMessageW". Be aware that the symbol
  ## lookup takes place in an injected thread; it's safer to use literal addresses
  ## when possible.
  #
  ## to handle the breakpoint, pass a block to this method, which will be called
  ## when the breakpoint hits.
  #
  ## breakpoints are always re-set after firing. If you don't want them to be
  ## re-set, unset them manually.
  def breakpoint_set(ip, callable=nil, &block)
    if not callable and block_given?
      callable = block
    end

    def_status = false

    ## This is usually 'Module!Function' or 'Module!0x1234'
    if @p.is_breakpoint_deferred(ip) == true
        def_status = true
    else
        def_status = false
        ip = @p.get_proc_remote(ip)
    end

    ## If we cant immediately set the breakpoint
    ## mark it as deferred and wait till later
    ## Sometimes *_proc_remote() will return the
    ## name indicating failure (just in case)
    if ip == 0 or ip == 0xFFFFFFFF or ip.kind_of? String
      def_status = true
    else
      def_status = false
    end

    ## Dont want duplicate breakpoint objects
    @breakpoints.each_key { |k| if k == ip then return end }
    bp = Breakpoint.new(@p, ip, def_status, callable)
    @breakpoints[ip] = bp
  end

  ## Clear a breakpoint by ip
  def breakpoint_clear(ip)
    bp = @breakpoints[ip]

    if bp.nil?
        return nil
    end

    bp.uninstall
    @breakpoints.delete(ip)
  end 
  
  ## handle a breakpoint event:
  ## call handlers for the breakpoint, step past and reset it.
  def on_breakpoint(ev)
      ctx = context(ev)
      eip = ev.exception_address

      if eip == @ntdll_dbg_break_point
        return
      end

      @breakpoints[eip].uninstall

      ## Call the block passed to breakpoint_set
      ## which may have been passed through hook()
      @breakpoints[eip].call(ev, ctx)

      ## single step past the instruction...
      step(ev.tid, (onestep = lambda do |ev, ctx|
        if ev.exception_address != eip
          ## ... then re-install the breakpoint ...
          if not @breakpoints[eip].nil?
            @breakpoints[eip].install
          end
          ## ... and stop single-stepping.
          unstep(ev.tid, onestep)
        end
      end))

      ## Put execution back where it's supposed to be...
      Ragweed::Wrap32::open_thread(ev.tid) do |h|
        ctx = context(ev)
        ctx.eip = eip ## eip was ev.exception_address
        Ragweed::Wrap32::set_thread_context(h, ctx)
      end
  
    ## Tell the target to stop handling this event
    @handled = Ragweed::Wrap32::ContinueCodes::CONTINUE
  end

  ## FIX: this method should be a bit more descriptive in its naming
  def get_dll_name(ev)
    name = Ragweed::Wrap32::get_mapped_filename(@p.handle, ev.base_of_dll, 256)
    name.gsub!(/[\n]+/,'')
    name.gsub!(/[^\x21-\x7e]/,'')
    i = name.index('0')
    i ||= name.size
    return name[0, i]
  end

  def on_load_dll(ev)
    dll_name = get_dll_name(ev)

    @breakpoints.each_pair do |k,bp|
        if !bp.addr.kind_of?String
            next
        end

        m,f = bp.addr.split('!')

        if dll_name =~ /#{m}/i
            deferred = bp.deferred

            if deferred == true
                bp.deferred = false
            end

            new_addr = bp.deferred_install(ev.file_handle, ev.base_of_dll)

            if !new_addr.nil?
                @breakpoints[new_addr] = bp.dup
                @breakpoints.delete(k)
            end
        end
    end
  end

  ## handle a single-step event  
  def on_single_step(ev)
    ctx = context(ev)
    Ragweed::Wrap32::open_thread(ev.tid) do |h|
      ## re-enable the trap flag before our handler,
      ## which may choose to disable it.
      ctx.single_step(true)
      Ragweed::Wrap32.set_thread_context(h, ctx)
    end
    
    @steppers.each {|s| s.call(ev, ctx)}
        
    @handled = Ragweed::Wrap32::ContinueCodes::CONTINUE
  end

  ## This is sort of insane but most of my programs are just
  ## debug loops, so if you don't do this, they just hang when
  ## the target closes.
  def on_exit_process(ev)
    exit(1)
  end

  ## TODO: Implement each of these
  def on_create_process(ev)       end
  def on_create_thread(ev)        end
  def on_exit_thread(ev)          end
  def on_output_debug_string(ev)  end
  def on_rip(ev)                  end
  def on_unload_dll(ev)           end
  def on_guard_page(ev)           end
  def on_alignment(ev)            end
  def on_bounds(ev)               end
  def on_divide_by_zero(ev)       end
  def on_int_overflow(ev)         end
  def on_invalid_handle(ev)       end
  def on_illegal_instruction(ev)  end
  def on_priv_instruction(ev)     end
  def on_stack_overflow(ev)       end
  def on_heap_corruption(ev)      end
  def on_buffer_overrun(ev)       end
  def on_invalid_disposition(ev)  end

  ## Read through me to see all the random events
  ## you can hook in a subclass.
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
      when Ragweed::Wrap32::ExceptionCodes::GUARD_PAGE
        try(:on_guard_page, ev)
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
      when Ragweed::Wrap32::ExceptionCodes::ILLEGAL_INSTRUCTION
        try(:on_illegal_instruction, ev)
      when Ragweed::Wrap32::ExceptionCodes::PRIV_INSTRUCTION
        try(:on_priv_instruction, ev)
      when Ragweed::Wrap32::ExceptionCodes::STACK_OVERFLOW 
        try(:on_stack_overflow, ev)
      when Ragweed::Wrap32::ExceptionCodes::HEAP_CORRUPTION
        try(:on_heap_corruption, ev)
      when Ragweed::Wrap32::ExceptionCodes::BUFFER_OVERRUN
        try(:on_buffer_overrun, ev)
      when Ragweed::Wrap32::ExceptionCodes::INVALID_DISPOSITION 
        try(:on_invalid_disposition, ev)
      end
    end

    Ragweed::Wrap32::continue_debug_event(ev.pid, ev.tid, @handled)
    @handled = Ragweed::Wrap32::ContinueCodes::UNHANDLED
  end

  ## Debug loop
  def loop
    while true
      wait
    end
  end
  
  ## This is called implicitly by Debugger#wait.
  ## Attaches to the child process for debugging
  def attach
    Ragweed::Wrap32::debug_active_process(@p.pid)
    Ragweed::Wrap32::debug_set_process_kill_on_exit
    @attached = true
    @breakpoints.each_pair do |k, bp|
      bp.install
    end
  end

  ## Let go of the target.
  def release
    Ragweed::Wrap32::debug_active_process_stop(@p.pid)
    @attached = false
    @breakpoints.each_pair do |k, bp|
      bp.uninstall
    end
  end
end
