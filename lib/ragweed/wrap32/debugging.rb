module Ragweed::Wrap32
  module DebugCodes
    CREATE_PROCESS = 3
    CREATE_THREAD = 2
    EXCEPTION = 1
    EXIT_PROCESS = 5
    EXIT_THREAD = 4
    LOAD_DLL = 6
    OUTPUT_DEBUG_STRING = 8
    RIP = 9
    UNLOAD_DLL = 7
  end

  module ExceptionCodes
    ACCESS_VIOLATION = 0xC0000005
    BREAKPOINT = 0x80000003
    ALIGNMENT =  0x80000002
    SINGLE_STEP = 0x80000004
    BOUNDS = 0xC0000008
    DIVIDE_BY_ZERO = 0xC0000094
    INT_OVERFLOW = 0xC0000095
    INVALID_HANDLE = 0xC0000008
    PRIV_INSTRUCTION = 0xC0000096
    STACK_OVERFLOW = 0xC00000FD
    INVALID_DISPOSITION = 0xC0000026
  end

  module ContinueCodes
    CONTINUE = 0x10002
    BREAK = 0x40010008
    CONTROL_C = 0x40010005
    UNHANDLED = 0x80010001
    TERMINATE_THREAD = 0x40010003
    TERMINATE_PROCESS = 0x40010004
  end
end

class Ragweed::Wrap32::DebugEvent
  (FIELDS = [ :code,
              :pid,
              :tid,
              :file_handle,
              :process_handle,
              :thread_handle,
              :base,
              :offset,
              :info_size,
              :thread_base,
              :start_address,
              :image_name,
              :unicode,
              :exception_code,
              :exception_flags,
              :exception_record,
              :exception_address,
              :parameters,
              :exit_code,
              :dll_base,
              :rip_error,
              :rip_type]).each {|x| attr_accessor x}

  def initialize(str)
    @code, @pid, @tid = str.unpack("LLL")
    str.shift 12
    case @code
    when Ragweed::Wrap32::DebugCodes::CREATE_PROCESS 
      @file_handle, @process_handle, @thread_handle,
      @base, @offset,
      @info_size, @thread_base, @start_address,
      @image_name, @unicode = str.unpack("LLLLLLLLLH")
    when Ragweed::Wrap32::DebugCodes::CREATE_THREAD 
      @thread_handle, @thread_base, @start_address = str.unpack("LLL")
    when Ragweed::Wrap32::DebugCodes::EXCEPTION 
      @exception_code, @exception_flags,
      @exception_record, @exception_address, @parameter_count = str.unpack("LLLLL")
      str = str[20..-1]
      @parameters = []
      @parameter_count.times do
        begin
          @parameters << (str.unpack("L").first)
          str = str[4..-1]
        rescue;end
      end
    when Ragweed::Wrap32::DebugCodes::EXIT_PROCESS 
      @exit_code = str.unpack("L").first
    when Ragweed::Wrap32::DebugCodes::EXIT_THREAD 
      @exit_code = str.unpack("L").first
    when Ragweed::Wrap32::DebugCodes::LOAD_DLL
      @file_handle, @dll_base, @offset,
      @info_size, @image_name, @unicode = str.unpack("LLLLLH")
    when Ragweed::Wrap32::DebugCodes::OUTPUT_DEBUG_STRING 
    when Ragweed::Wrap32::DebugCodes::RIP 
      @rip_error, @rip_type = str.unpack("LL")
    when Ragweed::Wrap32::DebugCodes::UNLOAD_DLL 
      @dll_base = str.unpack("L").first
    else
      raise WinX.new(:wait_for_debug_event)
    end
  end

  def inspect_code(c)
    Ragweed::Wrap32::DebugCodes.to_key_hash[c].to_s || c.to_i
  end
  
  def inspect_exception_code(c)
    Ragweed::Wrap32::ExceptionCodes.to_key_hash[c].to_s || c.to_i.to_s(16)
  end

  def inspect_parameters(p)
    "[ " + p.map {|x| x.to_i.to_s}.join(", ") + " ]"
  end

  def inspect
    body = lambda do 
      FIELDS.map do |f| 
        if (v = send(f))
          f.to_s + "=" + (try("inspect_#{f.to_s}".intern, v) || v.to_i.to_s(16))
        end
      end.compact.join(" ")
    end
    
    "#<DebugEvent #{body.call}>"
  end
end

module Ragweed::Wrap32
  class << self
    def wait_for_debug_event(ms=1000)
      buf = "\x00" * 1024
      r = CALLS["kernel32!WaitForDebugEvent:PL=L"].call(buf, ms)
      raise WinX.new(:wait_for_debug_event) if r == 0 and get_last_error != 121
      return Ragweed::Wrap32::DebugEvent.new(buf) if r != 0
      return nil
    end

    def continue_debug_event(pid, tid, code)
      r = CALLS["kernel32!ContinueDebugEvent:LLL=L"].call(pid, tid, code)
      raise WinX.new(:continue_debug_event) if r == 0
      return r
    end

    def debug_active_process(pid)
      r = CALLS["kernel32!DebugActiveProcess:L=L"].call(pid)
      raise WinX.new(:debug_active_process) if r == 0
      return r
    end

    def debug_set_process_kill_on_exit(val=0)
      r = CALLS["kernel32!DebugSetProcessKillOnExit:L=L"].call(val)
      raise WinX.new(:debug_set_process_kill_on_exit) if r == 0
      return r
    end

    def debug_active_process_stop(pid)
      # don't care about failure
      CALLS["kernel32!DebugActiveProcessStop:L=L"].call(pid)
    end

    def flush_instruction_cache(h, v1=0, v2=0)
      CALLS["kernel32!FlushInstructionCache:LLL=L"].call(h, v1, v2)
    end
  end
end
