module Ragweed; end
module Ragweed::Rasm
  # Ruby inline assembler.
  class Bblock
    # Don't call this directly; use Bblock#make
    def initialize
      @insns = Ragweed::Rasm::Subprogram.new
    end

    # Wrap the methods of Rasm::Subprogram we care about:

    # Assemble the instructions, which also calculates appropriate
    # jump labels.
    def assemble; @insns.assemble; end

    # Disassemble the block (after it's been assembled) into
    # Frasm objects.
    def disassemble; @insns.disassemble; end

    # Generate a human-readable assembly listing.
    def listing; @insns.dump_disassembly; end

    # Append more instructions to a previously created block;
    # see Bblock#make
    def append(&block)
      instance_eval(&block)
    end

    # Takes a block argument, containing (mostly) assembly
    # instructions, as interpreted by Rasm. For example:
    #
    #     Bblock.make {
    #         push ebp
    #         mov  ebp, esp
    #         push ebx
    #         xor ebx, ebx
    #         addl esp, 4
    #         pop ebp
    #         ret
    #     }
    #
    # Each of those instructions is in fact the name of a class
    # in Rasm, lowercased; Bblock has a method_missing that catches
    # and instantiates them.
    #
    # Your block can contain arbitrary Ruby, but remember that it
    # runs in the scope of an anonymous class and so cannot directly
    # reference instance variables.
    def self.make(&block)
      c = Bblock.new
      c.instance_eval(&block)
      c
    end

    # method to fix collision with Kernel#sub properly
    def sub(*args)
      Ragwee::Rasm::Sub.new(*args)
    end

    def method_missing(meth, *args)
      k = Ragweed::Rasm.const_get(meth.to_s.capitalize)

      # If it's a class, it's an assembly opcode; otherwise,
      # it's a register or operand.
      if k.class == Class
        @insns << (k = k.new(*args))
      else
        k
      end
      k
    end
  end
end
