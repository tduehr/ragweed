## ------------------------------------------------------------------------

# Rasm: a half-assed X86 assembler.
#
# Rasm implements a small subset of the X86 instruction set, and only in
# simple encodings.
#
# However, Rasm implements enough X86 to do interesting things. I wrote it
# to inject trampoline functions and detours into remote processes. This
# is Ruby code; you'd never use it where performance matters. It's not
# enough to write a decent compiler, but it's enough to fuck up programs.
module Ragweed; end
module Ragweed::Rasm
  class NotImp < RuntimeError; end
  class Insuff < RuntimeError; end
  class BadArg < RuntimeError; end
  class TooMan < RuntimeError; end

  ## ------------------------------------------------------------------------

  def method_missing(meth, *args)
    Rasm.const_get(meth).new *args
  end

  ## ------------------------------------------------------------------------

  # A register target encoding, including [EAX+10] disp/indir
  class Register
    attr_accessor :code
    attr_accessor :disp
    attr_accessor :indir
    attr_accessor :byte
    attr_accessor :index
    attr_accessor :combined
    attr_accessor :scale

    EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI = [0,1,2,3,4,5,6,7]

    def self.comb(rc1, rc2)
      (rc1 << 8|rc2)
    end

    def scaled?; @scale and @scale > 0; end
    def combined?; @combined; end
    def reg1
      if combined?
        self.class.new((code>>8)&0xff)
      else
        self
      end
    end

    def reg2
      self.class.new(code&0xFF)
    end

    def *(x)
      if x.kind_of? Numeric
        ret = clone
        ret.scale = x
        return ret
      end
      raise BadArg, "bad operand type for *"
    end

    def +(x)
      if x.kind_of? Numeric
        ret = clone
        ret.disp = x
        return ret
      elsif x.kind_of? Register
        ret = clone
        ret.combined = true
        ret.indir = 1
        ret.scale = x.scale
        ret.code = self.class.comb(ret.code, x.code)
        return ret
      end

      raise BadArg, "bad operand type for +"
    end

    def -(x)
      ret = clone
      ret.disp = -x
      return ret
    end

    def regopts(opts={})
      if (v = opts[:disp])
        @disp = v
      end

      if (v = opts[:indir])
        @indir = v
      end

      if (v = opts[:byte])
        @byte = v
      end

      if (v = opts[:index])
        @index = v
      end

      return self
    end

    def self.eax(opts={}); Eax.clone.regopts opts; end
    def self.ecx(opts={}); Ecx.clone.regopts opts; end
    def self.edx(opts={}); Edx.clone.regopts opts; end
    def self.ebx(opts={}); Ebx.clone.regopts opts; end
    def self.esp(opts={}); Esp.clone.regopts opts; end
    def self.ebp(opts={}); Ebp.clone.regopts opts; end
    def self.esi(opts={}); Esi.clone.regopts opts; end
    def self.edi(opts={}); Edi.clone.regopts opts; end

    def initialize(code, opts={})
      @combined = false
      @code = code
      @disp = opts[:disp]
      @indir = opts[:indir]
      @byte = opts[:byte]
      @index = nil
      @scale = nil

      @indir = true if @disp
      disp = 0 if (@indir and not @disp)
    end

    def displace(disp)
      @disp = disp
      @indir = true
    end
  end

  ## ------------------------------------------------------------------------

  # Clone these to get access to the GPRs.
  # There's a very clean way to do this in Ruby, with like, module_eval
  # or something, but... time's a wasting.
  Eax = Register.new(Register::EAX)
  Ecx = Register.new(Register::ECX)
  Edx = Register.new(Register::EDX)
  Ebx = Register.new(Register::EBX)
  Esp = Register.new(Register::ESP)
  Ebp = Register.new(Register::EBP)
  Esi = Register.new(Register::ESI)
  Edi = Register.new(Register::EDI)
  def eax(opts={}); Register.eax opts; end
  def ecx(opts={}); Register.ecx opts; end
  def edx(opts={}); Register.edx opts; end
  def ebx(opts={}); Register.ebx opts; end
  def esp(opts={}); Register.esp opts; end
  def ebp(opts={}); Register.ebp opts; end
  def esi(opts={}); Register.esi opts; end
  def edi(opts={}); Register.edi opts; end
  module_function :eax
  module_function :ecx
  module_function :edx
  module_function :ebx
  module_function :esp
  module_function :ebp
  module_function :esi
  module_function :edi

  ## ------------------------------------------------------------------------

  # A code fragment. Push instructions into it. You can push Label
  # objects to create jump targets.
  class Subprogram < Array

    # Patch code offsets into the instructions to replace abstract
    # labels. Produces raw instruction stream.
    def assemble
      patches = {}
      buf = Ragweed::Sbuf.new

      each do |i|
        if i.kind_of? Instruction
          i.locate(buf.size)
          buf.straw i.to_s
        else
          patches[i] = buf.size
        end
      end

      select {|i| i.kind_of? Instruction}.each {|i| i.patch(patches)}
      buf.clear!
      select {|i| i.kind_of? Instruction}.each {|i|
        buf.straw(i.to_s)
      }

      buf.content
    end

    # Produce an array of insns. This is pretty much broken, because
    # it doesn't pre-patch the instructions.
    def disassemble
      select {|i| i.kind_of? Rasm::Instruction}.map {|i| i.decode}
    end

    def dump_disassembly
      disassemble.each_with_index do |insn, i|
        puts "#{ i } #{ insn.mnem }"
      end
    end
  end

  ## ------------------------------------------------------------------------

  # An immediate value. Basically just a Fixnum with a type wrapper.
  class Immed
    attr_reader :val
    def initialize(i); @val = i; end
    def method_missing(meth, *args); @val.send meth, *args; end
  end

  ## ------------------------------------------------------------------------

  # A label. Like an Immed with a default value and a different wrapper.
  class Label < Immed
    def initialize(i=rand(0x1FFFFFFF)); super i; end
  end

  ## ------------------------------------------------------------------------

  # An X86 instruction. For the most part, you do two things with an
  # instruction in Rasm: create it, and call to_s to get its raw value.
  class Instruction
    attr_accessor :src
    attr_accessor :dst

    def self.i(*args); self.new *args; end

    # Are the source/dest operands registers?
    def src_reg?; @src and @src.kind_of? Register; end
    def dst_reg?; @dst and @dst.kind_of? Register; end

    # Are the source/dest operands immediates?
    def src_imm?; @src and @src.kind_of? Immed; end
    def dst_imm?; @dst and @dst.kind_of? Immed; end

    # Are the source/dest operands labels?
    def src_lab?; @src and @src.kind_of? Label; end
    def dst_lab?; @dst and @dst.kind_of? Label; end

    def coerce(v)
      if v
        v = v.derive
        v = v.to_i if v.kind_of? Ptr
        if v.kind_of? Array
          v = v[0].clone
          v.indir = true
        end
        v = Immed.new(v) if v.number?
      end
      v
    end

    def src=(v); @src = coerce(v); end
    def dst=(v); @dst = coerce(v); end

    # Never called directly (see subclasses below)
    def initialize(x=nil, y=nil)
      @buf = Ragweed::Sbuf.new
      self.src = y
      self.dst = x
      @loc = nil
    end

    # Disassemble the instruction (mostly for testing)
    # def decode; Frasm::DistormDecoder.new.decode(self.to_s)[0]; end

    # What Subprogram#assemble uses to patch instruction locations.
    # Not user-servicable
    def locate(loc); @loc = loc; end
    # Not user-servicable
    def patch(patches)
      if @dst.kind_of? Label
        raise(BadArg, "need to have location first") if not @loc
        offset = patches[@dst.val] - @Loc
        @dst = Immed.new offset
        if offset < 0
          offset -= self.to_s
          @dst = Immed.new offset
        end
      end
    end

    # Calculate ModR/M bits for the instruction; this is
    # the source/destination operand encoding.
    def modrm(op1, op2)
      raise(BadArg, "two indirs") if op1.indir and op2.indir

      if op1.indir or op2.indir
        base = 0x80
        (op1.indir) ? (o, alt = [op1,op2]) : (o,alt = [op2,op1])
        if o.disp and (o.disp < 0x1000)
          base = 0x40
        end
        if (not o.disp) or (o.disp == 0)
          base = 0x0
        end
      end

      if op1.indir
        if op1.combined? or op1.scaled? or (op1.code == Register::EBP)
          sib(op1, op2, base)
        else
          return base + (op2.code << 3) + op1.code
        end
      elsif op2.indir
        if op2.combined? or op2.scaled? or (op2.code == Register::EBP)
          sib(op2, op1, base)
        else
          return base + (op1.code << 3) + op2.code
        end
      else
        return 0xc0 + (op2.code << 3) + op1.code
      end
    end

    def sib(indir, alt, base)
      modpart = (base+4) + (alt.code << 3)

      if indir.scaled?
        case indir.scale
        when 2
          sbase = 0x40
        when 4
          sbase = 0x80
        when 8
          sbase = 0xc0
        else
          raise BadArg, "scale must be 2, 4, or 8"
        end
      else
        sbase = 0
      end

      col = indir.reg1.code

      if indir.combined?
        row = indir.reg2.code
      else
        row = 4
      end

      pp [col,row,sbase]

      sibpart = sbase + (row << 3) + (col)

      return (modpart.chr) + (sibpart.chr)
    end

    # Add material to the instruction. Not user-servicable.
    def add(v, immed=false, half=false)
      return(nil) if not v

      if v.number?
        if (v < 0x100) and (v > -128) and not immed
          if v < 0
            @buf.stl8(v.sx8)
          else
            @buf.stl8(v)
          end
        else
          if not half
            @buf.stl32(v.sx32)
          else
            @buf.stl16(v.sx16)
          end
        end
      else
        @buf.straw v
      end
    end

    # Never called directly (see subclasses).
    def to_s; ret = @buf.content; @buf.clear!; ret; end
  end

  ## ------------------------------------------------------------------------

  # Jump to a relative offset (pos or neg), a register, or an address
  # in memory. Can take Labels instead of values, let patch figure out
  # the rest.
  class Jmp < Instruction
    # eb rel8
    # e9 rel
    # ff r/m
    # no far yet

    def initialize(x=nil); super x; end

    def to_s
      raise Insuff if not @dst
      if dst_imm? or dst_lab?
        if @dst.val < 0x100 and @dst.val > -127
          add(0xeb)
          add(@dst.val)
        else
          add(0xe9)
          add(@dst.val)
        end
      else
        add(0xff)
        add(modrm(@dst, Esp.clone))
        add(sx32(@dst.disp)) if @dst.disp
      end
      super
    end
  end

  ## ------------------------------------------------------------------------

  # Pop into a register
  class Pop < Instruction
    # 8f m32
    # 58+ # reg

    def initialize(dst=nil); super dst; end

    def to_s
      raise Insuff if not @dst
      raise(BadArg, "need register") if not dst_reg?

      if @dst.indir
        add(0x8f)
        add(modrm(@dst, Eax.clone))
        add(@dst.disp)
      else
        add(0x58 + @dst.code)
      end
      super
    end
  end

  ## ------------------------------------------------------------------------

  # Push a register, register-addressed memory location, or immediate
  # onto the stack.
  class Push < Instruction
    # ff r/m
    # 50+ r
    # 6a imm8
    # 68 imm

    def initialize( dst=nil); super dst; end

    def to_s
      raise Insuff if not @dst

      if dst_reg?
        if @dst.indir
          add(0xff)
          add(modrm(@dst, Esi.clone))
          add(@dst.disp)
        else
          add(0x50 + @dst.code)
        end
      elsif dst_imm?
        if @dst.val < 0x100
          add(0x6a)
          add(@dst.val)
        else
          add(0x68)
          add(@dst.val)
        end
      end
      super
    end
  end

  ## ------------------------------------------------------------------------

  # Call a register/memory location
  class Call < Instruction
    # e8 rel
    # ff/2 r/m
    # no far yet

    def initialize( dst=nil); super dst; end

    def to_s
      raise Insuff if not @dst

      if dst_reg?
        add(0xff)
        add(modrm(@dst, Edx.clone))
      else
        add(0xe8)
        add(@dst.val, true)
      end
      super
    end
  end

  ## ------------------------------------------------------------------------

  # Return; provide immediate for stack adjustment if you want.
  class Ret < Instruction
    # c3
    # c2 imm16

    def initialize( dst=nil); super dst; end

    def to_s
      if not @dst
        add(0xc3)
      elsif dst_imm?
        add(0xc2)
        add(@dst.val, true, true)
      else
        raise BadArg, "imm16 only"
      end
      super
    end
  end

  class Retn < Ret; end

  ## ------------------------------------------------------------------------

  # Wrapper class for arithmatic instructions. Never called directly;
  # see below.
  class Arith < Instruction
    # 05 imm32 to eax
    # 04 imm8 to al
    # 80/0 r/m8, imm8
    # 81/0 r/m, imm
    # no sign extend yet
    # 01 r/m, r
    # 03 r, r/m

    def initialize( dst=nil, src=nil); super dst, src; end

    def to_s
      if not @dst
        # fucked up
        if src_imm?
          if @src.val < 0x100
            add(@imp8)
            add(@src.val)
          else
            add(@imp)
            add(@src.val)
          end
        else
          raise BadArg, "need immed for implicit eax"
        end
      else
        if src_imm?
          if @src.val < 0x100
            add(@imm8)
            add(modrm(@dst, @x))
            add(@src.val)
          else
            add(@imm)
            add(modrm(@dst, @x))
            add(@src.val)
          end
        else
          raise(BadArg, "need two r/m") if not src_reg? or not dst_reg?
          raise(BadArg, "can't both be indir") if @src.indir and @dst.indir
          if @src.indir
            add(@rm)
            add(modrm(@dst, @src))
          else
            add(@mr)
            add(modrm(@dst, @src))
          end
        end
      end
      super
    end
  end

  ## ------------------------------------------------------------------------

  # ADD
  class Add < Arith
    def initialize(*args)
      super *args
      @imp8, @imp, @imm8, @imm, @rm, @mr = [0x04, 0x05, 0x83, 0x81, 0x03, 0x01]
      @x = Eax.clone
    end
  end
  Addl = Add

  ## ------------------------------------------------------------------------

  # SUB
  class Sub < Arith
    def initialize(*args)
      super *args
      @imp8, @imp, @imm8, @imm, @rm, @mr = [0x2c, 0x2d, 0x83, 0x81, 0x2b, 0x29]
      @x = Ebp.clone
    end
  end

  ## ------------------------------------------------------------------------

  # XOR
  class Xor < Arith
    def initialize(*args)
      super *args
      @imp8, @imp, @imm8, @imm, @rm, @mr = [0x34, 0x35, 0x83, 0x81, 0x33, 0x31]
      @x = Esi.clone
    end
  end
  ## ------------------------------------------------------------------------

  # AND
  class And < Arith
    def initialize(*args)
      super *args
      @imp8, @imp, @imm8, @imm, @rm, @mr = [0x24, 0x25, 0x83, 0x81, 0x23, 0x21]
      @x = Esp.clone
    end
  end

  ## ------------------------------------------------------------------------

  # OR
  class Or < Arith
    def initialize(*args)
      super *args
      @imp8, @imp, @imm8, @imm, @rm, @mr = [0x0c, 0x0d, 0x83, 0x81, 0x0b, 0x09]
      @x = Ecx.clone
    end
  end

  ## ------------------------------------------------------------------------

  # Test is AND + condition code
  class Test < Instruction
    # a8 imm8
    # a9 imm
    # f7/0, r/m
    # 85 r/m, r

    def initialize( dst=nil, src=nil); super(dst,src); end

    def to_s
      if not @dst
        raise(BadArg, "need imm for implied ax") if not src_imm?
        if @src.val < 0x100
          add(0xa8)
          add(@src.val)
        else
          add(0xa9)
          add(@src.val)
        end
      else
        if src_imm?
          add(0xf7)
          add(modrm(@dst.val, Eax.clone))
          add(@src.val)
        else
          add(0x85)
          add(modrm(@dst.val, @src))
        end
      end
      super
    end
  end

  ## ------------------------------------------------------------------------

  # CMP is SUB + condition code
  class Cmp < Instruction
    # 3c imm8
    # 3d imm
    # 80/7 r/m8, imm8
    # 81/7 r/m, imm
    # 83/7 r/m, imm8
    # 38 r/m8, r8
    # 39 r/m, r
    # 3a r8, r/m8
    # 3b r, r/m

    def initialize( dst=nil, src=nil); super dst, src; end

    def to_s
      if not @dst
        raise(BadArg, "need immed for implicit ax") if not src_imm?
        if @src.val < 0x100
          add(0x3c)
          add(@src.val)
        else
          add(0x3d)
          add(@src.val)
        end
      else
        raise(BadArg, "need reg dst") if not dst_reg?
        if src_imm?
          raise NotImp if @dst.byte
          if @src.val < 0x100
            add(0x83)
            add(modrm(@dst, Edi.clone))
            add(@src.val)
          else
            add(0x81)
            add(modrm(@dst, Edi.clone))
            add(@src.val)
          end
        else
          if @dst.indir
            add(0x39)
            add(modrm(@src, @dst))
            add(@dst.disp)
          else
            add(0x3b)
            add(modrm(@src, @dst))
            add(@dst.disp)
          end
        end
      end
      super
    end
  end

  ## ------------------------------------------------------------------------

  # Wrapper for INC and DEC, not called directly.
  class IncDec < Instruction
      # fe/0 r/m8
      # ff/0 r/m
      # 40+ (reg)

    def initialize( dst=nil); super dst; end

    def to_s
      raise Insuff if not @dst
      raise(BadArg, "need a register") if not dst_reg?

      if @dst.indir
        add(0xff)
        add(modrm(@dst, @var))
      else
        add(@bas + @dst.code)
      end
      super
    end
  end

  ## ------------------------------------------------------------------------

  # INC memory or register
  class Inc < IncDec
    def initialize(*args)
      super *args
      @var = Eax.clone
      @bas = 0x40
    end
  end

  ## ------------------------------------------------------------------------

  # DEC memory or register
  class Dec < IncDec
    def initialize(*args)
      super *args
      @var = Ecx.clone
      @bas = 0x48
    end
  end

  ## ------------------------------------------------------------------------

  # MOV, from reg to mem or v/v, or imm to reg, v/v
  class Mov < Instruction
    # 89 r/m, r
    # 8b r, r/m
    # b8+ r, imm
    # c7+ r/m, imm
    def to_s
      raise Insuff if not @src or not @dst
      raise NotImp if (src_reg? and @src.index) or (dst_reg? and @dst.index)

      if src_imm?
        if @dst.indir
          add(0xc7)
          add(@dst.code)
          add(@src.val)
        else
          add(0xb8 + @dst.code)
          add(@src.val, true)
        end
      elsif dst_imm?
        raise BadArg, "mov to immed"
      else
        raise(BadArg, "two r/m") if @src.indir and @dst.indir
        if not @src.indir and not @dst.indir
          add(0x89)
          add(modrm(@dst, @src))
        elsif @src.indir # ie, ld
          add(0x8b)
          add(modrm(@dst, @src))
          add(@src.disp)
        elsif @dst.indir # ie, st
          add(0x89)
          add(modrm(@dst, @src))
          add(@dst.disp)
        end
      end
      super
    end

    def initialize( x=nil, y=nil); super x, y; end
  end

  ## ------------------------------------------------------------------------

  # Wrapper for the shift operations below.
  class Shift < Instruction
    once = nil
    bycl = nil
    imm = nil
    x = nil

    def initialize( dst=nil, src=nil); super dst, src; end

    def to_s
      raise Insuff if not @dst
      raise(BadArg, "need reg dst") if not dst_reg?

      if not @src
        add(@once)
        add(modrm(@dst, @x))
      else
        if src_imm?
          add(@imm)
          add(modrm(@dst, @x))
          add(@src.val)
        else
          add(@bycl)
          add(modrm(@dst, @x))
        end
      end
      super
    end

    def magic(x, y, z, r); @once, @bycl, @imm, @x = [x,y,z,r.clone]; end
  end

  # XXX looks wrong

  # Left arith shift
  class Sal < Shift; def initialize(*args); super *args; magic 0xd1, 0xd3, 0xc1, Esp; end; end

  # Right arith shift
  class Sar < Shift; def initialize(*args); super *args; magic 0xd1, 0xd3, 0xc1, Edi; end; end

  # Left logic shift
  class Shl < Shift; def initialize(*args); super *args; magic 0xd1, 0xd3, 0xc1, Esp; end; end

  # Right logic shift
  class Shr < Shift; def initialize(*args); super *args; magic 0xd1, 0xd3, 0xc1, Ebp; end; end

  ## ------------------------------------------------------------------------

  # NOP
  class Nop < Instruction
    # 90
    def initialize; super; end

    def to_s
      add(0x90)
      super
    end
  end

  ## ------------------------------------------------------------------------

  # NOT a register
  class Not < Instruction
    # f7/2 r/m

    def initialize( dst=nil); super dst; end

    def to_s
      raise Insuff if not @dst
      raise(BadArg, "need reg for not") if not dst_reg?

      add(0xf7)
      add(modrm(@dst, Edx.clone))
      super
    end
  end

  ## ------------------------------------------------------------------------

  # Load a memory address from a register into another register;
  # uses memory notation, but is a pure arith insn
  class Lea < Instruction
    # 8d r, m

    def initialize( dst=nil, src=nil); super dst, src; end

    def to_s
      raise Insuff if not @src or not @dst
      raise(BadArg, "need reg src") if not src_reg?
      raise(BadArg, "need indirected src") if not @src.indir

      add(0x8d)
      add(modrm(@dst, @src))
      add(@src.disp)
      super
    end
  end

  ## ------------------------------------------------------------------------

  # Wrapper for conditional jumps, see below
  class Jcc < Instruction

    def m; [nil,nil]; end
    def initialize( dst)
      super dst
      @short, @near = m()
    end

    def to_s
      raise Insuff if not @dst
      raise(BadArg, "need immed") if not dst_imm? and not dst_lab?

      if @dst.val < 0
        if @dst.val.abs & 0x80
          add(0x0f)
          add(@near)
          add(@dst.sx32)
        else
          add(@short)
          add(@dst.sx8)
        end
      else
        if @dst.val < 0x100
          add(@short)
          add(@dst.val)
        else
          add(0x0f)
          add(@near)
          add(@dst.val, true)
        end
      end
      super
    end
  end

  # Somewhere in the SDM there's a table of what condition codes
  # each of these check.

  # Above
  class Ja < Jcc; def m; [0x77, 0x87]; end; end
  # Above/eq
  class Jae <Jcc; def m; [0x73, 0x83]; end; end
  # Below
  class Jb < Jcc; def m; [0x72, 0x82]; end; end
  # Below/eq
  class Jbe < Jcc;  def m; [0x76,  0x86]; end; end
  # Carry
  class Jc < Jcc;  def m; [0x72,  0x82]; end; end
  # Equal
  class Je < Jcc;  def m; [0x74,  0x84]; end; end
  # Greater (SIGNED)
  class Jg < Jcc;  def m; [0x7f,  0x8f]; end; end
  # Greater/eq (SIGNED)
  class Jge < Jcc;  def m; [0x7d,  0x8d]; end; end
  # Less (SIGNED)
  class Jl < Jcc;  def m; [0x7c,  0x8c]; end; end
  # Less/eq (SIGNED)
  class Jle < Jcc;  def m; [0x7e,  0x8e]; end; end
  # Not above
  class Jna < Jcc;  def m; [0x76,  0x86]; end; end
  # Not above/eq
  class Jnae < Jcc;  def m; [0x72,  0x82]; end; end
  # Not below
  class Jnb < Jcc;  def m; [0x73,  0x83]; end; end
  # Not below/eq
  class Jnbe < Jcc;  def m; [0x77,  0x87]; end; end
  # Not carry
  class Jnc < Jcc;  def m; [0x73,  0x83]; end; end
  # Not equal
  class Jne < Jcc;  def m; [0x75,  0x85]; end; end
  # Not greater (SIGNED)
  class Jng < Jcc;  def m; [0x7e,  0x8e]; end; end
  # Not greater/eq (SIGNED)
  class Jnge < Jcc;  def m; [0x7c,  0x8c]; end; end
  # Not less (SIGNED)
  class Jnl < Jcc;  def m; [0x7d,  0x8d]; end; end
  # Not less/eq (SIGNED)
  class Jnle < Jcc;  def m; [0x7f,  0x8f]; end; end
  # Not overflow
  class Jno < Jcc;  def m; [0x71,  0x81]; end; end
  # Not parity
  class Jnp < Jcc;  def m; [0x7b,  0x8b]; end; end
  # Not sign
  class Jns < Jcc;  def m; [0x79,  0x89]; end; end
  # Not zero
  class Jnz < Jcc;  def m; [0x75,  0x85]; end; end
  # Overflow
  class Jo < Jcc;  def m; [0x70,  0x80]; end; end
  # Parity
  class Jp < Jcc;  def m; [0x7a,  0x8a]; end; end
  # Parity/eq
  class Jpe < Jcc;  def m; [0x7a,  0x8a]; end; end
  # Parity/overflow
  class Jpo < Jcc;  def m; [0x7b,  0x8b]; end; end
  # Signed
  class Js < Jcc;  def m; [0x78,  0x88]; end; end
  # Zero
  class Jz < Jcc;  def m; [0x74,  0x84]; end; end

  ## ------------------------------------------------------------------------

  class Pushf < Instruction
      # 9c pushfd

      def initialize; end
      def to_s
          raise(TooMan, "too many arguments") if @src or @dst
          add(0x9c)
      end
  end

  ## ------------------------------------------------------------------------

  class Popf < Instruction
      # 9d popfd

      def initialize; end
      def to_s
          raise(TooMan, "too many arguments") if @src or @dst
          add(0x9d)
      end
  end

  ## ------------------------------------------------------------------------

  # INT 3, mostly, but will do INT X
  class Int < Instruction
    ## cc int 3
    ## cd imm int n
    ## ce int 4 notimp

    def initialize(dst=nil); super dst; end

    def to_s
      raise(TooMan, "too many arguments for int") if @src
      raise(BadArg, "int takes immed") if @dst and not dst_imm?

      if @dst
        raise(BadArg, "need 8 bit immed") if @dst.val >= 0x100
        if @dst.val == 3
          add(0xcc)
        elsif @dst.val == 4
          add(0xce)
        else
          add(0xcd)
          add(@dst.val)
        end
      else
        add(0xcc)
      end
      super
    end
  end
end
