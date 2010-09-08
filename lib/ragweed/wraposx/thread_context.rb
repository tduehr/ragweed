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
  
  FLAVORS = {
    X86_THREAD_STATE32    => {:size => 64, :count =>16},
    X86_FLOAT_STATE32     => {:size => 64, :count =>16},
    X86_EXCEPTION_STATE32 => {:size => 12, :count =>3},
    X86_DEBUG_STATE32     => {:size => 64, :count =>8},
    X86_THREAD_STATE64    => {:size => 168, :count =>42},
    X86_FLOAT_STATE64     => {:size => 64, :count =>16},
    X86_EXCEPTION_STATE64 => {:size => 16, :count =>4},
    X86_DEBUG_STATE64     => {:size => 128, :count =>16},
    X86_THREAD_STATE      => {:size => 176, :count =>44},
    X86_FLOAT_STATE       => {:size => 64, :count =>16},
    X86_EXCEPTION_STATE   => {:size => 24, :count =>6},
    X86_DEBUG_STATE       => {:size => 136, :count =>18}
  }
  class << self
    #factory method to get a ThreadContext variant
    def self.get(flavor,tid)
      found = false
      klass = self.constants.detect{|c| con = self.const_get(c); con.kind_of?(Class) && (flavor == con.const_get(:FLAVOR))}
      if klass.nil?
        raise Ragwed::Wraposx::KErrno::INVALID_ARGUMENT
      else
        klass.get(tid)
      end
    end
  end
  
  module ThreadContextMixins
    def initialize(str=nil)
      refresh(str) if str
    end
    
    # (re)loads the data from str
    def refresh(str)
      fields = self.class.const_get :FIELDS
      if str and not str.empty?
        str.unpack(fields.map {|x| x[1]}.join("")).each_with_index do |val, i|
          raise "i is nil" if i.nil?
          instance_variable_set "@#{ fields[i][0] }".intern, val
        end            
      end
      self
    end

    def to_s
      flds = self.class.const_get(:FIELDS)
      flds.map {|f| send(f[0])}.pack(flds.map{|x| x[1].join('')})
    end

    def get(h)
      Ragweed::Wraposx::thread_suspend(h)
      refresh(Wraposx::thread_get_state_raw(h, self.class.const_get(:FLAVOR)))
      Ragweed::Wraposx::thread_resume(h)
      self
    end

    def set(h)
      Ragweed::Wraposx::thread_suspend(h)
      r = Wraposx::thread_set_state_raw(h, self.to_s, self.class.const_get(:FLAVOR))
      Ragweed::Wraposx::thread_resume(h)
      self
    end

    def inspect
      body = lambda do
        self.class.const_get(:FIELDS).map do |f|
          "#{f[0]}=#{send(f[0]).to_s(16)}"
        end.join(", ")
      end
      "#<#{self.class.name.split('::').last(2).join('::')} #{body.call}>"
    end

    module ClassMethods
      def get(h)
        Ragweed::Wraposx::thread_suspend(h)
        r = self.new(Ragweed::Wraposx::thread_get_state_raw(h,self.const_get(:FLAVOR)))
        Ragweed::Wraposx::thread_resume(h)
        r
      end
    end
    
    def self.included(klass)
        klass.extend(ClassMethods)
    end
  end
end

class Ragweed::Wraposx::ThreadContext::State

  FLAVOR = 7

  def self.get(h)
    Ragweed::Wraposx::thread_suspend(h)
    s = Ragweed::Wraposx::thread_get_state_raw(h, FLAVOR)
    flavor = s.unpack("L").first
    case flavor
    when Ragweed::Wraposx::ThreadContext::X86_THREAD_STATE32
      ret = Ragweed::Wraposx::ThreadContext::State32.new(s.unpack("LLa*").last)
    when Ragweed::Wraposx::ThreadContext::X86_THREAD_STATE64
      ret = Ragweed::Wraposx::ThreadContext::State64.new(s.unpack("LLa*").last)
    else
      raise Ragwed::Wraposx::KErrno::INVALID_ARGUMENT
    end
    Ragweed::Wraposx::thread_resume(h)
  end
  
  # maybe add a self.set?
end

class Ragweed::Wraposx::ThreadContext::State32
  include Ragweed::Wraposx::ThreadContext::ThreadContextMixins
  
  FLAVOR = 1
  
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

  (FIELDS = [ [:eax, "L"],
              [:ebx, "L"],
              [:ecx, "L"],
              [:edx, "L"],
              [:edi, "L"],
              [:esi, "L"],
              [:ebp, "L"],
              [:esp, "L"],
              [:ss, "L"],
              [:eflags, "L"],
              [:eip, "L"],
              [:cs, "L"],
              [:ds, "L"],
              [:es, "L"],
              [:fs, "L"],
              [:gs, "L"]]).each {|x| attr_accessor x[0]}

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
      @eflags |= Flags::TRAP
    else
      @eflags &= ~(Flags::TRAP)
    end
  end
end

class Ragweed::Wraposx::ThreadContext::State64
  include Ragweed::Wraposx::ThreadContext::ThreadContextMixins
  
  FLAVOR = 4
  
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

  (FIELDS = [ [:rax, "Q"],
              [:rbx, "Q"],
              [:rcx, "Q"],
              [:rdx, "Q"],
              [:rdi, "Q"],
              [:rsi, "Q"],
              [:rbp, "Q"],
              [:rsp, "Q"],
              [:r8, "Q"],
              [:r9, "Q"],
              [:r10, "Q"],
              [:r11, "Q"],
              [:r12, "Q"],
              [:r13, "Q"],
              [:r14, "Q"],
              [:r15, "Q"],
              [:rip, "Q"],
              [:rflags, "Q"],
              [:cs, "Q"],
              [:fs, "Q"],
              [:gs, "Q"]]).each {|x| attr_accessor x[0]}

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

class Ragweed::Wraposx::ThreadContext::Debug

  FLAVOR = 12

  def self.get(h)
    Ragweed::Wraposx::thread_suspend(h)
    s = Ragweed::Wraposx::thread_get_state_raw(h, FLAVOR)
    flavor = s.unpack("L").first
    case flavor
    when Ragweed::Wraposx::ThreadContext::X86_DEBUG_STATE32
      ret = Ragweed::Wraposx::ThreadContext::Debug32.new(s.unpack("LLa*").last)
    when Ragweed::Wraposx::ThreadContext::X86_DEBUG_STATE64
      ret = Ragweed::Wraposx::ThreadContext::Debug64.new(s.unpack("LLa*").last)
    else
      raise Ragwed::Wraposx::KErrno::INVALID_ARGUMENT
    end
    Ragweed::Wraposx::thread_resume(h)
  end
end

class Ragweed::Wraposx::ThreadContext::Debug32
  include Ragweed::Wraposx::ThreadContext::ThreadContextMixins

  FLAVOR = 10

  (FIELDS = [ [:dr0, "L"],
              [:dr1, "L"],
              [:dr2, "L"],
              [:dr3, "L"],
              [:dr4, "L"],
              [:dr5, "L"],
              [:dr6, "L"],
              [:dr7, "L"]]).each {|x| attr_accessor x[0]}

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

class Ragweed::Wraposx::ThreadContext::Debug64
  include Ragweed::Wraposx::ThreadContext::ThreadContextMixins

  FLAVOR = 11

  (FIELDS = [ [:dr0, "Q"],
              [:dr1, "Q"],
              [:dr2, "Q"],
              [:dr3, "Q"],
              [:dr4, "Q"],
              [:dr5, "Q"],
              [:dr6, "Q"],
              [:dr7, "Q"]]).each {|x| attr_accessor x[0]}

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

class Ragweed::Wraposx::ThreadContext::Exception
  FLAVOR = 9
  
  def self.get(h)
    Ragweed::Wraposx::thread_suspend(h)
    s = Ragweed::Wraposx::thread_get_state_raw(h, FLAVOR)
    flavor = s.unpack("L").first
    case flavor
    when Ragweed::Wraposx::ThreadContext::X86_EXCEPTION_STATE32
      ret = Ragweed::Wraposx::ThreadContext::Debug32.new(s.unpack("LLa*").last)
    when Ragweed::Wraposx::ThreadContext::X86_EXCEPTION_STATE64
      ret = Ragweed::Wraposx::ThreadContext::Debug64.new(s.unpack("LLa*").last)
    else
      raise Ragwed::Wraposx::KErrno::INVALID_ARGUMENT
    end
    Ragweed::Wraposx::thread_resume(h)
  end
end

class Ragweed::Wraposx::ThreadContext::Exception32
  include Ragweed::Wraposx::ThreadContext::ThreadContextMixins

  FLAVOR = 3

  (FIELDS = [ [:trapno, "L"],
              [:err, "L"],
              [:faultvaddr, "L"]]).each {|x| attr_accessor x[0]}

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

class Ragweed::Wraposx::ThreadContext::Exception64
  include Ragweed::Wraposx::ThreadContext::ThreadContextMixins

  FLAVOR = 6

  (FIELDS = [ [:trapno, "L"],
              [:err, "L"],
              [:faultvaddr, "Q"]]).each {|x| attr_accessor x[0]}

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

class Ragweed::Wraposx::ThreadContext::Float
  FLAVOR = 8
  
  def self.get(h)
    Ragweed::Wraposx::thread_suspend(h)
    s = Ragweed::Wraposx::thread_get_state_raw(h, FLAVOR)
    flavor = s.unpack("L").first
    case flavor
    when Ragweed::Wraposx::ThreadContext::X86_FLOAT_STATE32
      ret = Ragweed::Wraposx::ThreadContext::Float32.new(s.unpack("LLa*").last)
    when Ragweed::Wraposx::ThreadContext::X86_FLOAT_STATE64
      ret = Ragweed::Wraposx::ThreadContext::Float64.new(s.unpack("LLa*").last)
    else
      raise Ragwed::Wraposx::KErrno::INVALID_ARGUMENT
    end
    Ragweed::Wraposx::thread_resume(h)
  end
end

class Ragweed::Wraposx::ThreadContext::Float32
  FLAVOR = 2
  
  (FIELDS = [ [:fpu_reserved, "a8"], # not really a string but an array of two ints fine this way since it's opaque
              [:fpu_fcw, "S"],
              [:fpu_fsw, "S"],
              [:fpu_ftw, "C"],
              [:fpu_rsrv1, "C"],
              [:fpu_fop, "S"],
              [:fpu_ip, "L"],
              [:fpu_cs, "S"],
              [:fpu_rsrv2, "S"],
              [:fpu_dp, "L"],
              [:fpu_ds, "S"],
              [:fpu_rsrv3, "S"],
              [:fpu_mxcsr, "L"],
              [:fpu_mxcsrmask, "L"],
              [:fpu_stmm0, "a16"],
              [:fpu_stmm1, "a16"],
              [:fpu_stmm2, "a16"],
              [:fpu_stmm3, "a16"],
              [:fpu_stmm4, "a16"],
              [:fpu_stmm5, "a16"],
              [:fpu_stmm6, "a16"],
              [:fpu_stmm7, "a16"],
              [:fpu_xmm0, "a16"],
              [:fpu_xmm1, "a16"],
              [:fpu_xmm2, "a16"],
              [:fpu_xmm3, "a16"],
              [:fpu_xmm4, "a16"],
              [:fpu_xmm5, "a16"],
              [:fpu_xmm6, "a16"],
              [:fpu_xmm7, "a16"],
              [:fpu_rsrv4, "a224"],
              [:fpu_reserved1, "L"]]).each {|x| attr_accessor x[0]}
  
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

class Ragweed::Wraposx::ThreadContext::Float64
  FLAVOR = 5
  
  (FIELDS = [ [:fpu_reserved, "a8"], # not really a string but an array of two ints fine this way since it's opaque
              [:fpu_fcw, "S"],
              [:fpu_fsw, "S"],
              [:fpu_ftw, "C"],
              [:fpu_rsrv1, "C"],
              [:fpu_fop, "S"],
              [:fpu_ip, "L"],
              [:fpu_cs, "S"],
              [:fpu_rsrv2, "S"],
              [:fpu_dp, "L"],
              [:fpu_ds, "S"],
              [:fpu_rsrv3, "S"],
              [:fpu_mxcsr, "L"],
              [:fpu_mxcsrmask, "L"],
              [:fpu_stmm0, "a16"],
              [:fpu_stmm1, "a16"],
              [:fpu_stmm2, "a16"],
              [:fpu_stmm3, "a16"],
              [:fpu_stmm4, "a16"],
              [:fpu_stmm5, "a16"],
              [:fpu_stmm6, "a16"],
              [:fpu_stmm7, "a16"],
              [:fpu_xmm0, "a16"],
              [:fpu_xmm1, "a16"],
              [:fpu_xmm2, "a16"],
              [:fpu_xmm3, "a16"],
              [:fpu_xmm4, "a16"],
              [:fpu_xmm5, "a16"],
              [:fpu_xmm6, "a16"],
              [:fpu_xmm7, "a16"],
              [:fpu_xmm8, "a16"],
              [:fpu_xmm9, "a16"],
              [:fpu_xmm10, "a16"],
              [:fpu_xmm11, "a16"],
              [:fpu_xmm12, "a16"],
              [:fpu_xmm13, "a16"],
              [:fpu_xmm14, "a16"],
              [:fpu_xmm15, "a16"],
              [:fpu_rsrv4, "a96"],
              [:fpu_reserved1, "L"]]).each {|x| attr_accessor x[0]}
  
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

module Ragweed::Wraposx

  # define i386_THREAD_STATE_COUNT   ((mach_msg_type_number_t)( sizeof (i386_thread_state_t) / sizeof (int) ))
  # I386_THREAD_STATE_COUNT = 16
  # I386_THREAD_STATE = 1
  # REGISTER_SYMS = [:eax,:ebx,:ecx,:edx,:edi,:esi,:ebp,:esp,:ss,:eflags,:eip,:cs,:ds,:es,:fs,:gs]

  class << self

    # # Returns a Hash of the thread's registers given a thread id.
    # #
    # # kern_return_t   thread_get_state
    # #                (thread_act_t                     target_thread,
    # #                 thread_state_flavor_t                   flavor,
    # #                 thread_state_t                       old_state,
    # #                 mach_msg_type_number_t         old_state_count);
    # def thread_get_state(thread)
    #   state_arr = ("\x00"*SIZEOFINT*I386_THREAD_STATE_COUNT).to_ptr
    #   count = ([I386_THREAD_STATE_COUNT].pack("I_")).to_ptr
    #   r = CALLS["libc!thread_get_state:IIPP=I"].call(thread, I386_THREAD_STATE, state_arr, count).first
    #   raise KernelCallError.new(:thread_get_state, r) if r != 0
    #   r = state_arr.to_s(I386_THREAD_STATE_COUNT*SIZEOFINT).unpack("I_"*I386_THREAD_STATE_COUNT)
    #   regs = Hash.new
    #   I386_THREAD_STATE_COUNT.times do |i|
    #     regs[REGISTER_SYMS[i]] = r[i]
    #   end
    #   return regs
    # end

    # Returns string representation of a thread's registers for unpacking given a thread id
    #
    # kern_return_t   thread_get_state
    #                (thread_act_t                     target_thread,
    #                 thread_state_flavor_t                   flavor,
    #                 thread_state_t                       old_state,
    #                 mach_msg_type_number_t         old_state_count);
    def thread_get_state_raw(thread,flavor)
      state_arr = ("\x00"*SIZEOFINT*I386_THREAD_STATE_COUNT).to_ptr
      count = ([I386_THREAD_STATE_COUNT].pack("I_")).to_ptr
      r = CALLS["libc!thread_get_state:IIPP=I"].call(thread, I386_THREAD_STATE, state_arr, count).first
      raise KernelCallError.new(:thread_get_state, r) if r != 0
      return state_arr.to_s(I386_THREAD_STATE_COUNT*SIZEOFINT)
    end

    # # Sets the register state of thread from a Hash containing it's values.
    # #
    # # kern_return_t   thread_set_state
    # #                (thread_act_t                     target_thread,
    # #                 thread_state_flavor_t                   flavor,
    # #                 thread_state_t                       new_state,
    # #                 target_thread                  new_state_count);
    # def thread_set_state(thread, state)
    #   s = Array.new
    #   I386_THREAD_STATE_COUNT.times do |i|
    #     s << state[REGISTER_SYMS[i]]
    #   end
    #   s = s.pack("I_"*I386_THREAD_STATE_COUNT).to_ptr
    #   r = CALLS["libc!thread_set_state:IIPI=I"].call(thread, I386_THREAD_STATE, s, I386_THREAD_STATE_COUNT).first
    #   raise KernelCallError.new(:thread_set_state, r) if r!= 0
    # end

    # Sets the register state of thread from a packed string containing it's values.
    #
    # kern_return_t   thread_set_state
    #                (thread_act_t                     target_thread,
    #                 thread_state_flavor_t                   flavor,
    #                 thread_state_t                       new_state,
    #                 target_thread                  new_state_count);
    def thread_set_state_raw(thread, flavor, state)
      r = CALLS["libc!thread_set_state:IIPI=I"].call(thread, flavor, state.to_ptr, ThreadContext::FLAVORS[flavor][:count]).first
      raise KernelCallError.new(:thread_set_state, r) if r!= 0
    end
  end
end
