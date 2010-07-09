module Ragweed::Wrap32
  module EFlags
    CARRY = (1<< 0)
    X0 = (1<< 1)
    PARITY = (1<< 2)
    X1 = (1<< 3)
    ADJUST = (1<< 4)
    X2 = (1<< 5)
    ZERO = (1<< 6)
    SIGN = (1<< 7)
    TRAP = (1<< 8)
    INTERRUPT = (1<< 9)
    DIRECTION = (1<< 10)
    OVERFLOW = (1<< 11)
    IOPL1 = (1<< 12)
    IOPL2 = (1<< 13)
    NESTEDTASK = (1<< 14)
    X3 = (1<< 15)
    RESUME = (1<< 16)
    V86MODE = (1<< 17)
    ALIGNCHECK = (1<< 18)
    VINT = (1<< 19)
    VINTPENDING = (1<< 20)
    CPUID = (1<< 21)
  end
  
  module ContextFlags
    I386 = 0x10000
    CONTROL = 1
    INTEGER = 2
    SEGMENTS = 4
    FLOATING_POINT = 8
    DEBUG_REGISTERS = 0x10

    FULL = (I386|CONTROL|INTEGER|SEGMENTS)
    DEBUG = (FULL|DEBUG_REGISTERS)
  end
end

class Ragweed::Wrap32::ThreadContext
  (FIELDS = [ [:context_flags, "L"],
              [:dr0, "L"],
              [:dr1, "L"],
              [:dr2, "L"],
              [:dr3, "L"],
              [:dr6, "L"],
              [:dr7, "L"],
              [:floating_save, "a112"],
              [:seg_gs, "L"],
              [:seg_gs, "L"],
              [:seg_es, "L"],
              [:seg_ds, "L"],
              [:edi, "L"],
              [:esi, "L"],
              [:ebx, "L"],
              [:edx, "L"],
              [:ecx, "L"],
              [:eax, "L"],
              [:ebp, "L"],
              [:eip, "L"],
              [:seg_cs, "L"],
              [:eflags, "L"],
              [:esp, "L"],
              [:seg_ss, "L"],
              [:spill, "a1024"]]).each {|x| attr_accessor x[0]}

  def initialize(str=nil)
    refresh(str) if str
  end

  def refresh(str)
    if str
      str.unpack(FIELDS.map {|x| x[1]}.join("")).each_with_index do |val, i|
        instance_variable_set "@#{ FIELDS[i][0] }".intern, val
      end            
    end
  end

  def to_s
    FIELDS.map {|f| send(f[0])}.pack(FIELDS.map {|x| x[1]}.join(""))
  end

  def self.get(h)
    self.new(Ragweed::Wrap32::get_thread_context_raw(h))
  end

  def get(h)
    refresh(Ragweed::Wrap32::get_thread_context_raw(h))
  end

  def set(h)
    Ragweed::Wrap32::set_thread_context_raw(h, self.to_s)
  end

  def inspect
    body = lambda do
      FIELDS.map do |f|
        val = send(f[0])
        "#{f[0]}=#{val.to_s(16) rescue val.to_s.hexify}"
      end.join(", ")
    end
    "#<ThreadContext #{body.call}>"
  end

  def dump(&block)
    maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }      
#    maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

    string =<<EOM
-----------------------------------------------------------------------
CONTEXT:
    EIP: #{self.eip.to_s(16).rjust(8, "0")}
    EAX: #{self.eax.to_s(16).rjust(8, "0")}
    EBX: #{self.ebx.to_s(16).rjust(8, "0")}
    ECX: #{self.ecx.to_s(16).rjust(8, "0")}
    EDX: #{self.edx.to_s(16).rjust(8, "0")}
    EDI: #{self.edi.to_s(16).rjust(8, "0")}
    ESI: #{self.esi.to_s(16).rjust(8, "0")}
    EBP: #{self.ebp.to_s(16).rjust(8, "0")}
    ESP: #{self.esp.to_s(16).rjust(8, "0")}
    EFL: #{self.eflags.to_s(2).rjust(32, "0")} #{Ragweed::Wrap32::EFlags.flag_dump(self.eflags)}
EOM
  end

  def single_step(v=true)
    if v
      @eflags |= Ragweed::Wrap32::EFlags::TRAP
    else
      @eflags &= ~(Ragweed::Wrap32::EFlags::TRAP)
    end
  end
end

module Ragweed::Wrap32
  class << self
    def get_thread_context_raw(h)
      ctx = [Ragweed::Wrap32::ContextFlags::DEBUG,0,0,0,0,0,0,"\x00"*112,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"\x00"*1024].pack("LLLLLLLa112LLLLLLLLLLLLLLLLa1024")
      ret = CALLS["kernel32!GetThreadContext:LP=L"].call(h, ctx)
      if ret != 0
        return ctx
      else
        raise WinX.new(:get_thread_context)
      end
    end

    def set_thread_context_raw(h, c)
      buf = c.to_s
      ret = CALLS["kernel32!SetThreadContext:LP=L"].call(h, buf)
      raise WinX.new(:set_thread_context) if ret == 0
      return ret
    end

    def str2context(str)
      ret = OpenStruct.new
      ret.ContextFlags,
      ret.Dr0, 
      ret.Dr1,
      ret.Dr2,
      ret.Dr3,
      ret.Dr6,
      ret.Dr7,
      ret.FloatControlWord,
      ret.FloatStatusWord,
      ret.FloatTagWord,
      ret.FloatErrorOffset,
      ret.FloatErrorSelector,
      ret.FloatDataOffset,
      ret.FloatDataSelector,
      ret.FloatRegisterArea,
      ret.FloatCr0NpxState,
      ret.SegGs,
      ret.SegFs,
      ret.SegEs,
      ret.SegDs,
      ret.Edi,
      ret.Esi,
      ret.Ebx,
      ret.Edx,
      ret.Ecx,
      ret.Eax,
      ret.Ebp,
      ret.Eip,
      ret.SegCs,
      ret.EFlags,
      ret.Esp,
      ret.SegSs,
      ret.Spill = str.unpack("LLLLLLLLLLLLLLA80LLLLLLLLLLLLLLLLLA1024")
      return ret
    end

    # Retrieve the running context of a thread given its handle, returning a 
    # struct that mostly contains register values. Note that this will suspend
    # and then resume the thread. Useful (among many other things) to sample
    # EIP values to see what the code is doing.
    def get_thread_context(h)
      ctx = [Ragweed::Wrap32::ContextFlags::DEBUG,0,0,0,0,0,0,"\x00"*112,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,"\x00"*1024].pack("LLLLLLLa112LLLLLLLLLLLLLLLLa1024")
      suspend_thread(h)
      ret = CALLS["kernel32!GetThreadContext:LP=L"].call(h, ctx)
      resume_thread(h)
      if ret != 0
        return str2context(ctx)
      else
        raise WinX.new(:get_thread_context)
      end
    end
  end
end
