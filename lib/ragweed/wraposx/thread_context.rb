# 127          ((x == x86_THREAD_STATE32)     || \
# 128           (x == x86_FLOAT_STATE32)      || \
# 129           (x == x86_EXCEPTION_STATE32)  || \
# 130           (x == x86_DEBUG_STATE32)      || \
# 131           (x == x86_THREAD_STATE64)     || \
# 132           (x == x86_FLOAT_STATE64)      || \
# 133           (x == x86_EXCEPTION_STATE64)  || \
# 134           (x == x86_DEBUG_STATE64)      || \
# 135           (x == x86_THREAD_STATE)       || \
# 136           (x == x86_FLOAT_STATE)        || \
# 137           (x == x86_EXCEPTION_STATE)    || \
# 138           (x == x86_DEBUG_STATE)        || \

module Ragweed; end
module Ragweed::Wraposx::ThreadContext

  X86_THREAD_STATE32    = 1
  X86_FLOAT_STATE32     = 2
  X86_EXCEPTION_STATE32 = 3
  X86_DEBUG_STATE32     = 10
  X86_THREAD_STATE64    = 4
  X86_FLOAT_STATE64     = 5
  X86_EXCEPTION_STATE64 = 6
  X86_DEBUG_STATE64     = 11
  # factory requests (return 32 or 64 bit structure)
  X86_THREAD_STATE      = 7
  X86_FLOAT_STATE       = 8
  X86_EXCEPTION_STATE   = 9
  X86_DEBUG_STATE       = 12
  THREAD_STATE_NONE     = 13

  # depricated request names
  I386_THREAD_STATE     = X86_THREAD_STATE32
  I386_FLOAT_STATE      = X86_FLOAT_STATE32
  I386_EXCEPTION_STATE  = X86_EXCEPTION_STATE32

  # struct x86_state_hdr {
  #         int     flavor;
  #         int     count;
  # };
  class X86StateHdr < FFI::Struct
    include Ragweed::FFIStructInclude
    layout :flavor, :int,
           :count, :int
  end

  # _STRUCT_X86_THREAD_STATE32
  # {
  #     unsigned int        eax;
  #     unsigned int        ebx;
  #     unsigned int        ecx;
  #     unsigned int        edx;
  #     unsigned int        edi;
  #     unsigned int        esi;
  #     unsigned int        ebp;
  #     unsigned int        esp;
  #     unsigned int        ss;
  #     unsigned int        eflags;
  #     unsigned int        eip;
  #     unsigned int        cs;
  #     unsigned int        ds;
  #     unsigned int        es;
  #     unsigned int        fs;
  #     unsigned int        gs;
  # };
  class State32 < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 1
    layout :eax, :uint,
           :ebx, :uint,
           :ecx, :uint,
           :edx, :uint,
           :edi, :uint,
           :esi, :uint,
           :ebp, :uint,
           :esp, :uint,
           :ss, :uint,
           :eflags, :uint,
           :eip, :uint,
           :cs, :uint,
           :ds, :uint,
           :es, :uint,
           :fs, :uint,
           :gs, :uint
  
    module Flags
      CARRY =         0x1
      X0 =            0x2
      PARITY =        0x4
      X1 =            0x8
      ADJUST =        0x10
      X2 =            0x20
      ZERO =          0x40
      SIGN =          0x80
      TRAP =          0x100
      INTERRUPT =     0x200
      DIRECTION =     0x400
      OVERFLOW =      0x800
      IOPL1 =         0x1000
      IOPL2 =         0x2000
      NESTEDTASK =    0x4000
      X3 =            0x8000
      RESUME =        0x10000
      V86MODE =       0x20000
      ALIGNCHECK =    0x40000
      VINT =          0x80000
      VINTPENDING =   0x100000
      CPUID =         0x200000
    end

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      CONTEXT:
      EIP: #{self.eip.to_s(16).rjust(8, "0")} #{maybe_dis.call(self.eip)}

      EAX: #{self.eax.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.eax)}
      EBX: #{self.ebx.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.ebx)}
      ECX: #{self.ecx.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.ecx)}
      EDX: #{self.edx.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.edx)}
      EDI: #{self.edi.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.edi)}
      ESI: #{self.esi.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.esi)}
      EBP: #{self.ebp.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.ebp)}
      ESP: #{self.esp.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.esp)}
      EFL: #{self.eflags.to_s(2).rjust(32, "0")} #{Flags.flag_dump(self.eflags)}
EOM
    end

    # sets/clears the TRAP flag
    def single_step(v=true)
      if v
        self.eflags |= Flags::TRAP
      else
        self.eflags &= ~(Flags::TRAP)
      end
    end
  end

  # _STRUCT_X86_THREAD_STATE64
  # {
  #         __uint64_t      rax;
  #         __uint64_t      rbx;
  #         __uint64_t      rcx;
  #         __uint64_t      rdx;
  #         __uint64_t      rdi;
  #         __uint64_t      rsi;
  #         __uint64_t      rbp;
  #         __uint64_t      rsp;
  #         __uint64_t      r8;
  #         __uint64_t      r9;
  #         __uint64_t      r10;
  #         __uint64_t      r11;
  #         __uint64_t      r12;
  #         __uint64_t      r13;
  #         __uint64_t      r14;
  #         __uint64_t      r15;
  #         __uint64_t      rip;
  #         __uint64_t      rflags;
  #         __uint64_t      cs;
  #         __uint64_t      fs;
  #         __uint64_t      gs;
  # };
  class State64 < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 4  
    layout :rax, :uint64,
           :rbx, :uint64,
           :rcx, :uint64,
           :rdx, :uint64,
           :rdi, :uint64,
           :rsi, :uint64,
           :rbp, :uint64,
           :rsp, :uint64,
           :r8, :uint64,
           :r9, :uint64,
           :r10, :uint64,
           :r11, :uint64,
           :r12, :uint64,
           :r13, :uint64,
           :r14, :uint64,
           :r15, :uint64,
           :rip, :uint64,
           :rflags, :uint64,
           :cs, :uint64,
           :fs, :uint64,
           :gs, :uint64,

    module Flags
      CARRY =         0x1
      X0 =            0x2
      PARITY =        0x4
      X1 =            0x8
      ADJUST =        0x10
      X2 =            0x20
      ZERO =          0x40
      SIGN =          0x80
      TRAP =          0x100
      INTERRUPT =     0x200
      DIRECTION =     0x400
      OVERFLOW =      0x800
      IOPL1 =         0x1000
      IOPL2 =         0x2000
      NESTEDTASK =    0x4000
      X3 =            0x8000
      RESUME =        0x10000
      V86MODE =       0x20000
      ALIGNCHECK =    0x40000
      VINT =          0x80000
      VINTPENDING =   0x100000
      CPUID =         0x200000
    end

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      CONTEXT:
      RIP: #{self.rip.to_s(16).rjust(16, "0")} #{maybe_dis.call(self.eip)}

      RAX: #{self.rax.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.eax)}
      RBX: #{self.rbx.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.ebx)}
      RCX: #{self.rcx.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.ecx)}
      RDX: #{self.rdx.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.edx)}
      RDI: #{self.rdi.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.edi)}
      RSI: #{self.rsi.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.esi)}
      RBP: #{self.rbp.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.ebp)}
      RSP: #{self.rsp.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.esp)}
      RFL: #{(self.rflags & 0xffffffff).to_s(2).rjust(32, "0")} #{Flags.flag_dump(self.rflags & 0xffffffff)}
EOM
    end

    # sets/clears the TRAP flag
    def single_step(v=true)
      if v
        @rflags |= Flags::TRAP
      else
        @rflags &= ~(Flags::TRAP)
      end
    end
  end

  class UnionThreadState < FFI::Union
    include Ragweed::FFIStructInclude
    layout :ts32, Ragweed::Wraposx::ThreadContext::State32,
           :ts64, Ragweed::Wraposx::ThreadContext::State64
  end

  class State < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 7
    layout :tsh, Ragweed::Wraposx::ThreadContext::X86StateHdr,
           :uts, Ragweed::Wraposx::ThreadContext::UnionThreadState
  end

  # _STRUCT_X86_DEBUG_STATE32
  # {
  #         unsigned int    dr0;
  #         unsigned int    dr1;
  #         unsigned int    dr2;
  #         unsigned int    dr3;
  #         unsigned int    dr4;
  #         unsigned int    dr5;
  #         unsigned int    dr6;
  #         unsigned int    dr7;
  # };
  class Debug32 < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 10
    layout :dr0, :uint,
           :dr1, :uint,
           :dr2, :uint,
           :dr3, :uint,
           :dr4, :uint,
           :dr5, :uint,
           :dr6, :uint,
           :dr7, :uint

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      CONTEXT:
      DR0: #{self.dr0.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.dr0)}
      DR1: #{self.dr1.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.dr1)}
      DR2: #{self.dr2.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.dr2)}
      DR3: #{self.dr3.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.dr3)}
      DR4: #{self.dr4.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.dr4)}
      DR5: #{self.dr5.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.dr5)}
      DR6: #{self.dr6.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.dr6)}
      DR7: #{self.dr7.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.dr7)}
EOM
    end
  end

  # _STRUCT_X86_DEBUG_STATE64
  # {
  #         __uint64_t      dr0;
  #         __uint64_t      dr1;
  #         __uint64_t      dr2;
  #         __uint64_t      dr3;
  #         __uint64_t      dr4;
  #         __uint64_t      dr5;
  #         __uint64_t      dr6;
  #         __uint64_t      dr7;
  # };
  class Debug64 < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 11
    layout :dr0, :uint64,
           :dr1, :uint64,
           :dr2, :uint64,
           :dr3, :uint64,
           :dr4, :uint64,
           :dr5, :uint64,
           :dr6, :uint64,
           :dr7, :uint64

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      CONTEXT:
      DR0: #{self.dr0.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.dr0)}
      DR1: #{self.dr1.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.dr1)}
      DR2: #{self.dr2.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.dr2)}
      DR3: #{self.dr3.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.dr3)}
      DR4: #{self.dr4.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.dr4)}
      DR5: #{self.dr5.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.dr5)}
      DR6: #{self.dr6.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.dr6)}
      DR7: #{self.dr7.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.dr7)}
EOM
    end
  end

  class UnionDebugState < FFI::Union
    include Ragweed::FFIStructInclude
    layout :ds32, Ragweed::Wraposx::ThreadContext::Debug32,
           :ds64, Ragweed::Wraposx::ThreadContext::Debug64
  end

  class Debug < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 12
    layout :dsh, Ragweed::Wraposx::ThreadContext::X86StateHdr,
           :uds, Ragweed::Wraposx::ThreadContext::UnionDebugState
  end

  # _STRUCT_X86_EXCEPTION_STATE32
  # {
  #     unsigned int        trapno;
  #     unsigned int        err;
  #     unsigned int        faultvaddr;
  # };
  class Exception32 < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 3
    layout :trapno, :uint,
           :err, :uint,
           :faltvaddr, :uint

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      CONTEXT:
      trapno:     #{self.trapno.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.trapno)}
      err:        #{self.err.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.err)}
      faultvaddr: #{self.faultvaddr.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.faultvaddr)}
EOM
    end
  end

  # _STRUCT_X86_EXCEPTION_STATE64
  # {
  #     unsigned int        trapno;
  #     unsigned int        err;
  #     __uint64_t          faultvaddr;
  # };
  class Exception64 < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 6
    layout :trapno, :uint,
           :err, :uint,
           :faltvaddr, :uint64

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      CONTEXT:
      trapno:     #{self.trapno.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.trapno)}
      err:        #{self.err.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.err)}
      faultvaddr: #{self.faultvaddr.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.faultvaddr)}
EOM
    end
  end

  class UnionExceptionState < FFI::Union
    include Ragweed::FFIStructInclude
    layout :es32, Ragweed::Wraposx::ThreadContext::Exception32,
           :es64, Ragweed::Wraposx::ThreadContext::Exception64
  end

  class Exception < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 9
    layout :esh, Ragweed::Wraposx::ThreadContext::X86StateHdr,
           :ues, Ragweed::Wraposx::ThreadContext::UnionExceptionState
  end

  # _STRUCT_X86_FLOAT_STATE32
  # {
  #         int                     fpu_reserved[2];
  #         _STRUCT_FP_CONTROL      fpu_fcw;                /* x87 FPU control word */
  #         _STRUCT_FP_STATUS       fpu_fsw;                /* x87 FPU status word */
  #         __uint8_t               fpu_ftw;                /* x87 FPU tag word */
  #         __uint8_t               fpu_rsrv1;              /* reserved */ 
  #         __uint16_t              fpu_fop;                /* x87 FPU Opcode */
  #         __uint32_t              fpu_ip;                 /* x87 FPU Instruction Pointer offset */
  #         __uint16_t              fpu_cs;                 /* x87 FPU Instruction Pointer Selector */
  #         __uint16_t              fpu_rsrv2;              /* reserved */
  #         __uint32_t              fpu_dp;                 /* x87 FPU Instruction Operand(Data) Pointer offset */
  #         __uint16_t              fpu_ds;                 /* x87 FPU Instruction Operand(Data) Pointer Selector */
  #         __uint16_t              fpu_rsrv3;              /* reserved */
  #         __uint32_t              fpu_mxcsr;              /* MXCSR Register state */
  #         __uint32_t              fpu_mxcsrmask;          /* MXCSR mask */
  #         _STRUCT_MMST_REG        fpu_stmm0;              /* ST0/MM0   */
  #         _STRUCT_MMST_REG        fpu_stmm1;              /* ST1/MM1  */
  #         _STRUCT_MMST_REG        fpu_stmm2;              /* ST2/MM2  */
  #         _STRUCT_MMST_REG        fpu_stmm3;              /* ST3/MM3  */
  #         _STRUCT_MMST_REG        fpu_stmm4;              /* ST4/MM4  */
  #         _STRUCT_MMST_REG        fpu_stmm5;              /* ST5/MM5  */
  #         _STRUCT_MMST_REG        fpu_stmm6;              /* ST6/MM6  */
  #         _STRUCT_MMST_REG        fpu_stmm7;              /* ST7/MM7  */
  #         _STRUCT_XMM_REG         fpu_xmm0;               /* XMM 0  */
  #         _STRUCT_XMM_REG         fpu_xmm1;               /* XMM 1  */
  #         _STRUCT_XMM_REG         fpu_xmm2;               /* XMM 2  */
  #         _STRUCT_XMM_REG         fpu_xmm3;               /* XMM 3  */
  #         _STRUCT_XMM_REG         fpu_xmm4;               /* XMM 4  */
  #         _STRUCT_XMM_REG         fpu_xmm5;               /* XMM 5  */
  #         _STRUCT_XMM_REG         fpu_xmm6;               /* XMM 6  */
  #         _STRUCT_XMM_REG         fpu_xmm7;               /* XMM 7  */
  #         char                    fpu_rsrv4[14*16];       /* reserved */
  #         int                     fpu_reserved1;
  # };
  class Float32 < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 2
    layout :fpu_reserved, [:int, 2],
           :fpu_fcw, Ragweed::Wraposx::FpControl,
           :fpu_fsw, Ragweed::Wraposx::FpStatus,
           :fpu_ftw, :uint8,
           :fpu_rsrv1, :uint8,
           :fpu_fop, :uint16,
           :fpu_ip, :uint32,
           :fpu_cs, :uint16,
           :fpu_rsrv2, :uint16,
           :fpu_dp, :uint32,
           :fpu_ds, :uint16,
           :fpu_rsrv3, :uint16,
           :fpu_mxcsr, :uint32,
           :fpu_mxcsrmask, :uint32,
           :fpu_stmm0, Ragweed::Wraposx::MmstReg,
           :fpu_stmm1, Ragweed::Wraposx::MmstReg,
           :fpu_stmm2, Ragweed::Wraposx::MmstReg,
           :fpu_stmm3, Ragweed::Wraposx::MmstReg,
           :fpu_stmm4, Ragweed::Wraposx::MmstReg,
           :fpu_stmm5, Ragweed::Wraposx::MmstReg,
           :fpu_stmm6, Ragweed::Wraposx::MmstReg,
           :fpu_stmm7, Ragweed::Wraposx::MmstReg,
           :fpu_xmm0, Ragweed::Wraposx::XmmReg,
           :fpu_xmm1, Ragweed::Wraposx::XmmReg,
           :fpu_xmm2, Ragweed::Wraposx::XmmReg,
           :fpu_xmm3, Ragweed::Wraposx::XmmReg,
           :fpu_xmm4, Ragweed::Wraposx::XmmReg,
           :fpu_xmm5, Ragweed::Wraposx::XmmReg,
           :fpu_xmm6, Ragweed::Wraposx::XmmReg,
           :fpu_xmm7, Ragweed::Wraposx::XmmReg,
           :fpu_rsrv4, [:char, 14*16],
           :fpu_reserved1, :int

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      CONTEXT:
      trapno:     #{self.trapno.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.trapno)}
      err:        #{self.err.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.err)}
      faultvaddr: #{self.faultvaddr.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.faultvaddr)}
EOM
    end
  end

  # _STRUCT_X86_FLOAT_STATE64
  # {
  #         int                     fpu_reserved[2];
  #         _STRUCT_FP_CONTROL      fpu_fcw;                /* x87 FPU control word */
  #         _STRUCT_FP_STATUS       fpu_fsw;                /* x87 FPU status word */
  #         __uint8_t               fpu_ftw;                /* x87 FPU tag word */
  #         __uint8_t               fpu_rsrv1;              /* reserved */ 
  #         __uint16_t              fpu_fop;                /* x87 FPU Opcode */
  #         /* x87 FPU Instruction Pointer */
  #         __uint32_t              fpu_ip;                 /* offset */
  #         __uint16_t              fpu_cs;                 /* Selector */
  #         __uint16_t              fpu_rsrv2;              /* reserved */
  #         /* x87 FPU Instruction Operand(Data) Pointer */
  #         __uint32_t              fpu_dp;                 /* offset */
  #         __uint16_t              fpu_ds;                 /* Selector */
  #         __uint16_t              fpu_rsrv3;              /* reserved */
  #         __uint32_t              fpu_mxcsr;              /* MXCSR Register state */
  #         __uint32_t              fpu_mxcsrmask;          /* MXCSR mask */
  #         _STRUCT_MMST_REG        fpu_stmm0;              /* ST0/MM0   */
  #         _STRUCT_MMST_REG        fpu_stmm1;              /* ST1/MM1  */
  #         _STRUCT_MMST_REG        fpu_stmm2;              /* ST2/MM2  */
  #         _STRUCT_MMST_REG        fpu_stmm3;              /* ST3/MM3  */
  #         _STRUCT_MMST_REG        fpu_stmm4;              /* ST4/MM4  */
  #         _STRUCT_MMST_REG        fpu_stmm5;              /* ST5/MM5  */
  #         _STRUCT_MMST_REG        fpu_stmm6;              /* ST6/MM6  */
  #         _STRUCT_MMST_REG        fpu_stmm7;              /* ST7/MM7  */
  #         _STRUCT_XMM_REG         fpu_xmm0;               /* XMM 0  */
  #         _STRUCT_XMM_REG         fpu_xmm1;               /* XMM 1  */
  #         _STRUCT_XMM_REG         fpu_xmm2;               /* XMM 2  */
  #         _STRUCT_XMM_REG         fpu_xmm3;               /* XMM 3  */
  #         _STRUCT_XMM_REG         fpu_xmm4;               /* XMM 4  */
  #         _STRUCT_XMM_REG         fpu_xmm5;               /* XMM 5  */
  #         _STRUCT_XMM_REG         fpu_xmm6;               /* XMM 6  */
  #         _STRUCT_XMM_REG         fpu_xmm7;               /* XMM 7  */
  #         _STRUCT_XMM_REG         fpu_xmm8;               /* XMM 8  */
  #         _STRUCT_XMM_REG         fpu_xmm9;               /* XMM 9  */
  #         _STRUCT_XMM_REG         fpu_xmm10;              /* XMM 10  */
  #         _STRUCT_XMM_REG         fpu_xmm11;              /* XMM 11 */
  #         _STRUCT_XMM_REG         fpu_xmm12;              /* XMM 12  */
  #         _STRUCT_XMM_REG         fpu_xmm13;              /* XMM 13  */
  #         _STRUCT_XMM_REG         fpu_xmm14;              /* XMM 14  */
  #         _STRUCT_XMM_REG         fpu_xmm15;              /* XMM 15  */
  #         char                    fpu_rsrv4[6*16];        /* reserved */
  #         int                     fpu_reserved1;
  # };
  class Float64 < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 5
    layout :fpu_reserved, [:int, 2],
           :fpu_fcw, Ragweed::Wraposx::FpControl,
           :fpu_fsw, Ragweed::Wraposx::FpStatus,
           :fpu_ftw, :uint8,
           :fpu_rsrv1, :uint8,
           :fpu_fop, :uint16,
           :fpu_ip, :uint32,
           :fpu_cs, :uint16,
           :fpu_rsrv2, :uint16,
           :fpu_dp, :uint32,
           :fpu_ds, :uint16,
           :fpu_rsrv3, :uint16,
           :fpu_mxcsr, :uint32,
           :fpu_mxcsrmask, :uint32,
           :fpu_stmm0, Ragweed::Wraposx::MmstReg,
           :fpu_stmm1, Ragweed::Wraposx::MmstReg,
           :fpu_stmm2, Ragweed::Wraposx::MmstReg,
           :fpu_stmm3, Ragweed::Wraposx::MmstReg,
           :fpu_stmm4, Ragweed::Wraposx::MmstReg,
           :fpu_stmm5, Ragweed::Wraposx::MmstReg,
           :fpu_stmm6, Ragweed::Wraposx::MmstReg,
           :fpu_stmm7, Ragweed::Wraposx::MmstReg,
           :fpu_xmm0, Ragweed::Wraposx::XmmReg,
           :fpu_xmm1, Ragweed::Wraposx::XmmReg,
           :fpu_xmm2, Ragweed::Wraposx::XmmReg,
           :fpu_xmm3, Ragweed::Wraposx::XmmReg,
           :fpu_xmm4, Ragweed::Wraposx::XmmReg,
           :fpu_xmm5, Ragweed::Wraposx::XmmReg,
           :fpu_xmm6, Ragweed::Wraposx::XmmReg,
           :fpu_xmm7, Ragweed::Wraposx::XmmReg,
           :fpu_xmm8, Ragweed::Wraposx::XmmReg,
           :fpu_xmm9, Ragweed::Wraposx::XmmReg,
           :fpu_xmm10, Ragweed::Wraposx::XmmReg,
           :fpu_xmm11, Ragweed::Wraposx::XmmReg,
           :fpu_xmm12, Ragweed::Wraposx::XmmReg,
           :fpu_xmm13, Ragweed::Wraposx::XmmReg,
           :fpu_xmm14, Ragweed::Wraposx::XmmReg,
           :fpu_xmm15, Ragweed::Wraposx::XmmReg,
           :fpu_rsrv4, [:char, 6*16],
           :fpu_reserved1, :int
         
  
    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      CONTEXT:
      trapno:     #{self.trapno.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.trapno)}
      err:        #{self.err.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.err)}
      faultvaddr: #{self.faultvaddr.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.faultvaddr)}
EOM
    end
  end

  class UnionFloatState < FFI::Union
    include Ragweed::FFIStructInclude
    layout :fs32, Ragweed::Wraposx::ThreadContext::Float32,
           :fs64, Ragweed::Wraposx::ThreadContext::Float64
  end

  class Float < FFI::Struct
    include Ragweed::FFIStructInclude
    FLAVOR = 8
    layout :fsh, Ragweed::Wraposx::ThreadContext::X86StateHdr,
           :ufs, Ragweed::Wraposx::ThreadContext::UnionFloatState
  end

  FLAVORS = {
    X86_THREAD_STATE32    => {:size => 64, :count =>16, :class => State32},
    X86_FLOAT_STATE32     => {:size => 64, :count =>16, :class => Float32},
    X86_EXCEPTION_STATE32 => {:size => 12, :count =>3, :class => Exception32},
    X86_DEBUG_STATE32     => {:size => 64, :count =>8, :class => Debug32},
    X86_THREAD_STATE64    => {:size => 168, :count =>42, :class => State64},
    X86_FLOAT_STATE64     => {:size => 64, :count =>16, :class => Float64},
    X86_EXCEPTION_STATE64 => {:size => 16, :count =>4, :class => Exception64},
    X86_DEBUG_STATE64     => {:size => 128, :count =>16, :class => Debug64},
    X86_THREAD_STATE      => {:size => 176, :count =>44, :class => State},
    X86_FLOAT_STATE       => {:size => 64, :count =>16, :class => Float},
    X86_EXCEPTION_STATE   => {:size => 24, :count =>6, :class => Exception},
    X86_DEBUG_STATE       => {:size => 136, :count =>18, :class => Debug}
  }
end

module Ragweed::Wraposx

  module Libc
    extend FFI::Library
    ffi_lib FFI::Library::LIBC
    attach_function :thread_get_state, [:thread_act_t, :thread_state_flavor_t, :pointer, :mach_msg_type_number_t], :kern_return_t
    attach_function :thread_set_state, [:thread_act_t, :thread_state_flavor_t, :pointer, :mach_msg_type_number_t], :kern_return_t
  end

  class << self
    # Returns  a thread's registers for given a thread id
    #
    # kern_return_t   thread_get_state
    #                (thread_act_t                     target_thread,
    #                 thread_state_flavor_t                   flavor,
    #                 thread_state_t                       old_state,
    #                 mach_msg_type_number_t         old_state_count);
    def thread_get_state(thread,flavor)
      state = FFI::MemoryPointer.new Ragweed::Wraposx::ThreadContext::FLAVOR[flavor][:class], 1
      count = FFI::MemoryPointer.new(:int, 1).write_int Ragweed::Wraposx::ThreadContext::FLAVOR[flavor][:count]
      r = Libc.thread_get_state(thread, flavor, state, count)
      raise KernelCallError.new(:thread_get_state, r) if r != 0
      Ragweed::Wraposx::ThreadContext::FLAVOR[flavor][:class].new state
    end

    # Sets the register state of thread.
    #
    # kern_return_t   thread_set_state
    #                (thread_act_t                     target_thread,
    #                 thread_state_flavor_t                   flavor,
    #                 thread_state_t                       new_state,
    #                 mach_msg_number_t                  new_state_count);
    def thread_set_state(thread, flavor, state)
      r = Libc.thread_set_state(thread, flavor, state.to_ptr, ThreadContext::FLAVORS[flavor][:count])
      raise KernelCallError.new(:thread_set_state, r) if r!= 0
      Ragweed::Wraposx::ThreadContext::FLAVOR[flavor][:class].new state
    end
  end
end
