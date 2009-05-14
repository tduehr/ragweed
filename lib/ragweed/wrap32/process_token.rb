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

  class << self
    def open_process_token(h, access=Wrap32::TokenAccess::ADJUST_PRIVILEGES)
      outw = "\x00" * 4
      r = CALLS["advapi32!OpenProcessToken:LLP=L"].call(h, access, outw)
      raise WinX.new(:open_process_token) if r == 0
      return outw.unpack("L").first
    end

    def adjust_token_privileges(t, disable, *args)
      buf = [args.size].pack("L") + (args.map {|tup| tup.pack("QL") }.join(""))

      r = CALLS["advapi32!AdjustTokenPrivileges:LLPLPP=L"].
        call(t, disable, buf, buf.size, NULL, NULL)

      raise WinX.new(:adjust_token_privileges) if r == 0
    end

    def lookup_privilege_value(name)
      outw = "\x00" * 8
      r = CALLS["advapi32!LookupPrivilegeValueA:PPP=L"].call(NULL, name, outw)
      raise WinX.new(:lookup_privilege_value) if r == 0
      return outw.unpack("Q").first
    end
  end
end

class Ragweed::Wrap32::ProcessToken
  def initialize(p=nil)
    p ||= Wrap32::open_process(Wrap32::get_current_process_id)
    @h = Wrap32::open_process_token(p)
  end

  def grant(name)
    luid = Wrap32::lookup_privilege_value(name)
    Wrap32::adjust_token_privileges(@h, 0, [luid, Wrap32::PrivilegeAttribute::ENABLED])
  end
end
