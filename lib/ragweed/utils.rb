require 'iconv'

# @deprecated - unused this will be removed at some point.
class Range
  module RangeExtensions
    def each_backwards
      max.to_i.downto(min) {|i| yield i}
    end
  end
  include RangeExtensions
end

class Array
  module ArrayExtensions
    # Convert to hash
    ##
    def to_hash
        # too clever.
        # Hash[*self.flatten]

        h = Hash.new
        each do |k,v|
            h[k] = v
        end
        h
    end
  end
  include ArrayExtensions
end

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

    # This is from Topher Cyll's Stupd IRB tricks
    def mymethods
      (self.methods - self.class.superclass.methods).sort
    end

    def callable?; respond_to? :call; end
    def number?; kind_of? Numeric; end

    # while X remains callable, keep calling it to get its value
    def derive
      # also, don't drink and derive
      x = self
      while x.callable?
        x = x()
      end
      return x
    end
  end
  include ObjectExtensions
end

class String
  # to little endian 32bit integer
  def to_l32; unpack("L").first; end
  # to big endian 32bit integer
  def to_b32; unpack("N").first; end
  # to little endian 16bit short
  def to_l16; unpack("v").first; end
  # to big endian 16bit short
  def to_b16; unpack("n").first; end
  def to_u8; self[0]; end
  def shift_l32; shift(4).to_l32; end
  def shift_b32; shift(4).to_b32; end
  def shift_l16; shift(2).to_l16; end
  def shift_b16; shift(2).to_b16; end
  def shift_u8; shift(1).to_u8; end
  def to_utf16
      Iconv.iconv("utf-16LE", "utf-8", self).first + "\x00\x00"
  end
  def from_utf16
      ret = Iconv.iconv("utf-8", "utf-16le", self).first
      if ret[-1] == 0
          ret = ret[0..-2]
      end
  end
  alias_method :to_utf8, :from_utf16
  alias_method :to_ascii, :from_utf16
  def from_utf16_buffer
      self[0..index("\0\0\0")+2].from_utf16
  end
  
  def shift(count=1)
    return self if count == 0
    slice! 0..(count-1)
  end

  # Sometimes string buffers passed through Win32 interfaces come with
  # garbage after the trailing NUL; this method gets rid of that, like
  # String#trim
  def asciiz
    begin
      self[0..self.index("\x00")-1]
    rescue
      self
    end
  end
  
  def asciiz!; replace asciiz; end

  # Convert a string into hex characters
  def hexify
    self.unpack("H*").first
  end

  # Convert a string of raw hex characters (no %'s or anything) into binary
  def dehexify
    [self].pack("H*")
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

    # sign extend
    def sx8; ([self].pack "c").unpack("C").first; end
    def sx16; ([self].pack "s").unpack("S").first; end
    def sx32; ([self].pack "l").unpack("L").first; end

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
  def to_name_hash
    @name_hash ||= constants.map {|k| [k.intern, const_get(k.intern)]}.to_hash
  end

  def to_key_hash
    @key_hash ||= constants.map {|k| [const_get(k.intern), k.intern]}.to_hash
  end

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
