require 'ffi'

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

class Ragweed::Wrap32::RipInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :error, :ulong,
    :type, :ulong
end

class Ragweed::Wrap32::OutputDebugStringInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :debug_string_data, :ulong, # pointer
    :unicode, :uint16,
    :debug_string_length, :uint16
end

class Ragweed::Wrap32::UnloadDLLDebugInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :base_of_dll, :ulong
end

class Ragweed::Wrap32::LoadDLLDebugInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :file_handle, :ulong,
    :base_of_dll, :pointer,
    :debug_info_file_offset, :ulong,
    :debug_info_size, :ulong,
    :image_name, :pointer,
    :unicode, :uint16
end

class Ragweed::Wrap32::ExitProcessDebugInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :exit_code, :ulong
end

class Ragweed::Wrap32::ExitThreadDebugInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :exit_code, :ulong
end

class Ragweed::Wrap32::CreateProcessDebugInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :file_handle, :ulong,
    :process_handle, :ulong,
    :thread_handle, :ulong,
    :base_of_image, :pointer,
    :debug_info_file_offset, :ulong,
    :debug_info_size, :ulong,
    :thread_local_base, :pointer,
    :start_address, :pointer,
    :image_name, :pointer,
    :unicode, :uint16
end

class Ragweed::Wrap32::CreateThreadDebugInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :thread_handle, :ulong,
    :thread_local_base, :ulong,
    :start_address, :pointer
end

class Ragweed::Wrap32::ExceptionRecord < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :exception_code, :ulong,
    :exception_flags, :ulong,
    :exception_record, :pointer,
    :exception_address, :ulong,
    :number_of_parameters, :ulong,
    :exception_information, [:uint8, 15] ## EXCEPTION_MAXIMUM_PARAMETERS
end

class Ragweed::Wrap32::ExceptionDebugInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :exception_record, Ragweed::Wrap32::ExceptionRecord,
    :first_chance, :ulong
end

class Ragweed::Wrap32::DebugEventU < FFI::Union
    include Ragweed::FFIStructInclude
    layout :exception_debug_info, Ragweed::Wrap32::ExceptionDebugInfo,
    :create_thread_debug_info, Ragweed::Wrap32::CreateThreadDebugInfo,
    :create_process_debug_info, Ragweed::Wrap32::CreateProcessDebugInfo,
    :exit_thread_debug_info, Ragweed::Wrap32::ExitThreadDebugInfo,
    :exit_process_debug_info, Ragweed::Wrap32::ExitProcessDebugInfo,
    :load_dll_debug_info,  Ragweed::Wrap32::LoadDLLDebugInfo,
    :unload_dll_debug_info, Ragweed::Wrap32::UnloadDLLDebugInfo,
    :output_debug_string_info, Ragweed::Wrap32::OutputDebugStringInfo,
    :rip_info, Ragweed::Wrap32::RipInfo
end

class Ragweed::Wrap32::DebugEvent < FFI::Struct
    include Ragweed::FFIStructInclude

    layout :code, :ulong,
    :pid, :ulong,
    :tid, :ulong,
    :u, Ragweed::Wrap32::DebugEventU

    ## We have rubified this FFI structure by creating a bunch of instance
    ## variables that are normally only accessible via self.u.x.y which is
    ## a lot to type. You can still use that method however these instance
    ## variables should allow for considerably clearer code
    attr_accessor :base_of_dll, :base_of_image, :debug_info_file_offset, :debug_info_size, :exception_address, :exception_code,
                  :exception_flags, :exception_record, :exit_code, :file_handle, :image_name, :number_of_parameters, :parameters,
                  :process_handle, :rip_error, :rip_type, :start_address, :thread_local_base, :thread_handle, :thread_local_base,
                  :unicode

  def initialize(buf)
    super buf

    case self.code
    when Ragweed::Wrap32::DebugCodes::CREATE_PROCESS 
      @file_handle = self.u.create_process_debug_info.file_handle
      @process_handle = self.u.create_process_debug_info.process_handle
      @thread_handle = self.u.create_process_debug_info.thread_handle
      @base_of_image = self.u.create_process_debug_info.base_of_image
      @debug_info_file_offset = self.u.create_process_debug_info.debug_info_file_offset
      @debug_info_size = self.u.create_process_debug_info.debug_info_size
      @thread_local_base = self.u.create_process_debug_info.thread_local_base
      @start_address = self.u.create_process_debug_info.start_address
      @image_name = self.u.create_process_debug_info.image_name
      @unicode = self.u.create_process_debug_info.unicode

    when Ragweed::Wrap32::DebugCodes::CREATE_THREAD 
      @thread_handle = self.u.create_thread_debug_info.thread_handle
      @thread_local_base = self.u.create_thread_debug_info.thread_local_base
      @start_address = self.u.create_thread_debug_info.start_address

    when Ragweed::Wrap32::DebugCodes::EXCEPTION
      @exception_code = self.u.exception_debug_info.exception_record.exception_code
      @exception_flags = self.u.exception_debug_info.exception_record.exception_flags
      @exception_record = self.u.exception_debug_info.exception_record.exception_record
      @exception_address = self.u.exception_debug_info.exception_record.exception_address
      @number_of_parameters = self.u.exception_debug_info.exception_record.number_of_parameters

      @parameters = []

      self.number_of_parameters.times do |i|
            @parameters << self.u.exception_debug_info.exception_record.exception_information[i]
      end

    when Ragweed::Wrap32::DebugCodes::EXIT_PROCESS 
        @exit_code = self.u.exit_process_debug_info.exit_code

    when Ragweed::Wrap32::DebugCodes::EXIT_THREAD 
        @exit_code = self.u.exit_thread_debug_info.exit_code

    when Ragweed::Wrap32::DebugCodes::LOAD_DLL
        @file_handle = self.u.load_dll_debug_info.file_handle
        @base_of_dll = self.u.load_dll_debug_info.base_of_dll
        @debug_info_file_offset = self.u.load_dll_debug_info.debug_info_file_offset
        @debug_info_size = self.u.load_dll_debug_info.debug_info_size
        @image_name = self.u.load_dll_debug_info.image_name
        @unicode = self.u.load_dll_debug_info.unicode

    when Ragweed::Wrap32::DebugCodes::OUTPUT_DEBUG_STRING 
        ## 

    when Ragweed::Wrap32::DebugCodes::RIP 
        @rip_error = self.u.rip_info.rip_error
        @rip_type = self.u.rip_info.rip_type

    when Ragweed::Wrap32::DebugCodes::UNLOAD_DLL 
        @base_of_dll = self.u.unload_dll_debug_info.base_of_dll

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
          self.members.each_with_index do |m,i|
             "#{self.values[i].to_s.hexify} #{self.values[i].to_s.hexify}"
          end.join(", ")
      end
    "#<DebugEvent #{body.call}>"
  end
end

## Wrap the Win32 debugging specific APIs
module Ragweed::Wrap32
  module Win
    extend FFI::Library

    ffi_lib 'kernel32'
    ffi_convention :stdcall

    attach_function 'WaitForDebugEvent', [ :pointer, :ulong ], :ulong
    attach_function 'ContinueDebugEvent', [ :ulong, :ulong, :ulong ], :ulong
    attach_function 'DebugActiveProcess', [ :ulong ], :ulong
    attach_function 'DebugSetProcessKillOnExit', [ :ulong ], :ulong
    attach_function 'DebugActiveProcessStop', [ :ulong ], :ulong
    attach_function 'FlushInstructionCache', [ :ulong, :ulong, :ulong ], :ulong
  end

  class << self
    def wait_for_debug_event(ms=1000)
#      buf = FFI::MemoryPointer.new(Ragweed::Wrap32::DebugEvent, 1)
      buf = FFI::MemoryPointer.from_string("\x00" * 1024)
      r = Win.WaitForDebugEvent(buf, ms)
      raise WinX.new(:wait_for_debug_event) if r == 0 and get_last_error != 121
      return Ragweed::Wrap32::DebugEvent.new(buf) if r != 0
      return nil
    end

    def continue_debug_event(pid, tid, code)
      r = Win.ContinueDebugEvent(pid, tid, code)
      raise WinX.new(:continue_debug_event) if r == 0
      return r
    end

    def debug_active_process(pid)
      r = Win.DebugActiveProcess(pid)
      raise WinX.new(:debug_active_process) if r == 0
      return r
    end

    def debug_set_process_kill_on_exit(val=0)
      r = Win.DebugSetProcessKillOnExit(val)
      raise WinX.new(:debug_set_process_kill_on_exit) if r == 0
      return r
    end

    def debug_active_process_stop(pid)
      # don't care about failure
      Win.DebugActiveProcessStop(pid)
    end

    def flush_instruction_cache(h, v1=0, v2=0)
      Win.FlushInstructionCache(h, v1, v2)
    end
  end
end
