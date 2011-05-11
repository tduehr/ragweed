module Ragweed::Wrap32
  module TokenAccess
    ADJUST_DEFAULT = 128
    ADJUST_GROUPS = 64
    ADJUST_PRIVILEGES = 32
    ALL_ACCESS = 0xf00ff
    ASSIGN_PRIMARY = 1
    DUPLICATE = 2
    EXECUTE = 0x20000
    IMPERSONATE = 4
    QUERY = 8
    QUERY_SOURCE = 16
    READ = 0x20008
    WRITE = 0x200e0
  end

  module PrivilegeAttribute
    ENABLED = 0x2
    ENABLED_BY_DEFAULT = 0x1
    USED_FOR_ACCESS = 0x80000000
  end

  module Win
    extend FFI::Library

    ffi_lib 'kernel32','Advapi32'
    ffi_convention :stdcall
    attach_function 'OpenProcess', [ :long, :long, :long ], :long
    attach_function 'OpenProcessToken', [:long, :long, :pointer ], :long
    attach_function 'TerminateProcess', [:long, :uint], :long

    # ffi_lib 'advapi32'
    # ffi_convention :stdcall
    attach_function 'AdjustTokenPrivileges', [ :long, :long, :pointer, :long, :pointer, :pointer ], :long
    attach_function 'LookupPrivilegeValueA', [ :pointer, :pointer, :pointer ] ,:long
  end

  class << self

    def open_process_token(h, access=Ragweed::Wrap32::TokenAccess::ADJUST_PRIVILEGES)
      outw = "\x00" * 4
      r = Win.OpenProcessToken(h, access, outw)
      raise WinX.new(:open_process_token) if r == 0
      return outw.unpack("L").first
    end

    def adjust_token_privileges(t, disable, *args)
      buf = FFI::MemoryPointer.from_string( [args.size].pack("L") + (args.map {|tup| tup.pack("QL") }.join("")) )

      r = Win.AdjustTokenPrivileges(t, disable, buf, buf.size, nil, nil)

      raise WinX.new(:adjust_token_privileges) if r == 0
    end

    def lookup_privilege_value(name)
      namep = FFI::MemoryPointer.from_string(name)
      outw = FFI::MemoryPointer.new(:int64, 1)
      r = Win.LookupPrivilegeValueA(nil, namep, outw)
      r = Win.LookupPrivilegeValueA(nil, name, outw)
      raise WinX.new(:lookup_privilege_value) if r == 0
      outw.read_long_long
    end
  end
  
  def terminate_process(handle, exit_code)
    r = Win.TerminateProcess(handle, exit_code)
    raise WinX.new(:terminate_process) if r != 0
  end
end

class Ragweed::Wrap32::ProcessToken
  def initialize(p=nil)
    p ||= Ragweed::Wrap32::open_process(Ragweed::Wrap32::get_current_process_id)
    @h = Ragweed::Wrap32::open_process_token(p)
  end

  def grant(name)
    luid = Ragweed::Wrap32::lookup_privilege_value(name)
    Ragweed::Wrap32::adjust_token_privileges(@h, 0, [luid, Ragweed::Wrap32::PrivilegeAttribute::ENABLED])
  end
end
