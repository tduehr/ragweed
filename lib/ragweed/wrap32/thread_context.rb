require 'ffi'

module Ragweed::Wrap32
  module EFlags
    CARRY = (1 << 0)
    X0 = (1 << 1)
    PARITY = (1 << 2)
    X1 = (1 << 3)
    ADJUST = (1 << 4)
    X2 = (1 << 5)
    ZERO = (1 << 6)
    SIGN = (1 << 7)
    TRAP = (1 << 8)
    INTERRUPT = (1 << 9)
    DIRECTION = (1 << 10)
    OVERFLOW = (1 << 11)
    IOPL1 = (1 << 12)
    IOPL2 = (1 << 13)
    NESTEDTASK = (1 << 14)
    X3 = (1 << 15)
    RESUME = (1 << 16)
    V86MODE = (1 << 17)
    ALIGNCHECK = (1 << 18)
    VINT = (1 << 19)
    VINTPENDING = (1 << 20)
    CPUID = (1 << 21)
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

class Ragweed::Wrap32::ThreadContext < FFI::Struct
    ## This is defined in WinNt.h
    layout :context_flags, :long,
    :dr0, :long,
    :dr1, :long,
    :dr2, :long,
    :dr3, :long,
    :dr6, :long,
    :dr7, :long,
    :floating_save, [:uint8, 112], ## XXX need a structure for this
    :seg_gs, :long,
    :seg_fs, :long,
    :seg_es, :long,
    :seg_ds, :long,
    :edi, :long,
    :esi, :long,
    :ebx, :long,
    :edx, :long,
    :ecx, :long,
    :eax, :long,
    :ebp, :long,
    :eip, :long,
    :seg_cs, :long,
    :eflags, :long,
    :esp, :long,
    :seg_ss, :long,
    :spill, [:uint8, 512 ] ## MAXIMUM_SUPPORTED_EXTENSION

    ## XXX more helper methods here are needed

    def inspect
        body = lambda do
            self.members.each_with_index do |m,i|
                "#{self.members[i].to_s(16)} #{self.values[i].to_s.hexify}"
            end.join(", ")
        end
    end

    def dump(&block)
        maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }      
        #maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

        string =<<EOM
-----------------------------------------------------------------------
CONTEXT:
    EIP: #{self[:eip].to_s(16).rjust(8, "0")}
    EAX: #{self[:eax].to_s(16).rjust(8, "0")}
    EBX: #{self[:ebx].to_s(16).rjust(8, "0")}
    ECX: #{self[:ecx].to_s(16).rjust(8, "0")}
    EDX: #{self[:edx].to_s(16).rjust(8, "0")}
    EDI: #{self[:edi].to_s(16).rjust(8, "0")}
    ESI: #{self[:esi].to_s(16).rjust(8, "0")}
    EBP: #{self[:ebp].to_s(16).rjust(8, "0")}
    ESP: #{self[:esp].to_s(16).rjust(8, "0")}
    EFL: #{self[:eflags].to_s(2).rjust(32, "0")} #{Ragweed::Wrap32::EFlags.flag_dump(self[:eflags])}
EOM
    end

    def single_step(v=true)
        if v
          self[:eflags] |= Ragweed::Wrap32::EFlags::TRAP
        else
          self[:eflags] &= ~(Ragweed::Wrap32::EFlags::TRAP)
        end
    end
end

module Ragweed::Wrap32
  module Win
    extend FFI::Library

    ffi_lib 'kernel32'
    ffi_convention :stdcall
    attach_function 'SetThreadContext', [ :long, :pointer ], :long
    attach_function 'GetThreadContext', [ :long, :pointer ], :long
  end

  class << self
    def get_thread_context(h)
      #ctx = Ragweed::Wrap32::ThreadContext.new
      c = FFI::MemoryPointer.new(:uint8, Ragweed::Wrap32::ThreadContext.size)
      ctx = Ragweed::Wrap32::ThreadContext.new c
      ctx[:context_flags] = Ragweed::Wrap32::ContextFlags::DEBUG
      #suspend_thread(h)
      ret = Win.GetThreadContext(h, ctx)
      #resume_thread(h)
      if ret != 0
        return ctx
      else
        raise WinX.new(:get_thread_context)
      end
    end

    def set_thread_context(h, ctx)
      ret = Win.SetThreadContext(h, ctx) #ctx.to_s
      raise WinX.new(:set_thread_context) if ret == 0
      return ret
    end
  end
end
