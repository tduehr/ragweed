# These should probably be extensions to Module since that's the location of instance_eval and friends.
class Object
    module ObjectExtensions
      # Every object has a "singleton" class, which you can think
      # of as the class (ie, 1.metaclass =~ Fixnum) --- but that you
      # can modify and extend without fucking up the actual class.
      def metaclass; class << self; self; end; end
      def meta_eval(&blk) metaclass.instance_eval &blk; end
      def meta_def(name, &blk) meta_eval { define_method name, &blk }; end
      def try(meth, *args); send(meth, *args) if respond_to? meth; end

      def through(meth, *args)
          if respond_to? meth
              send(meth, *args)
          else
              self
          end
      end

      ## This is from Topher Cyll's Stupd IRB tricks
      def mymethods
        (self.methods - self.class.superclass.methods).sort
      end
    end
    include ObjectExtensions
end

class String
  def to_l32; unpack("L").first; end
  def to_b32; unpack("N").first; end
  def to_l16; unpack("v").first; end
  def to_b16; unpack("n").first; end
  def to_u8; self[0]; end
  def shift_l32; shift(4).to_l32; end
  def shift_b32; shift(4).to_b32; end
  def shift_l16; shift(2).to_l16; end
  def shift_b16; shift(2).to_b16; end
  def shift_u8; shift(1).to_u8; end
  
  def shift(count=1)
      return self if count == 0
      slice! 0..(count-1)
  end
end

class Integer
  module IntegerExtensions
    # Convert integers to binary strings
    def to_l32; [self].pack "L"; end
    def to_b32; [self].pack "N"; end
    def to_l16; [self].pack "v"; end
    def to_b16; [self].pack "n"; end
    def to_u8; [self].pack "C"; end
    def ffs
      i = 0
      v = self
      while((v >>= 1) != 0)
          i += 1
      end
      return i
    end
  end
  include IntegerExtensions
end

class Module
  def flag_dump(i)
    @bit_map ||= constants.map do |k|
      [k, const_get(k.intern).ffs]
    end.sort {|x, y| x[1] <=> y[1]}

    last = 0
    r = ""
    @bit_map.each do |tup|
      if((v = (tup[1] - last)) > 1)
        r << ("." * (v-1))
      end

      if((i & (1 << tup[1])) != 0)
        r << tup[0][0].chr
      else
        r << tup[0][0].chr.downcase
      end
      last = tup[1]
    end
    return r.reverse
  end
end