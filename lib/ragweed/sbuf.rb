# Stolen (mostly) from Net::SSH

# a* string a10 string 10 bytes A* string trimmed
# C uchar
# L native u32, l signed
# N BE u32, n 16
# Qq quad
# Ss native u16
# Vv LE u32

# Encapsulate a buffer of data with structured data accessors
class Ragweed::Sbuf
  attr_reader :content
  attr_accessor :position

  def self.from(*args)
    raise ArgumentError, "odd argument count" if args.length.odd?

    b = self.new
    while not args.empty?
      t = args.shift; v = args.shift
      if t == :raw
        b.straw(v)
      elsif v.kind_of? Array
        b.st t, *v
      else
        b.st t, v
      end
    end

    return b
  end

  def st(t, *args)
    send "st#{ t }", *args
  end

  def straw(*args)
    args.each do |raw|
      @content << raw.to_s
    end
    self
  end

  def initialize(opts={})
    @content = opts[:content] || ""
    @position = 0
  end

  def consume!(n=position)
    if(n >= length); clear!
    elsif n > 0
      @content = remainder(n)
      @position -= n
      @position = 0 if @position < 0
    end
    self
  end

  def ldraw(n=length)
    n = ((self.length) - position) if(position + n > length)
    @position += n
    @content[position-n, n]
  end

  def ld(t, *args)
    return ldraw(t) if t.kind_of? Numeric

    begin
      send "ld#{ t }", *args
    rescue => e
      case t.to_s
      when /^strz(\d+)?/
        n = $1.to_i if not $1.empty?
        n ||= 0
        ldsz(n)
      when /^strs(\d+)?/
        n = $1.to_i if not $1.empty?
        n ||= 0
        ldss(n)
      else
        raise e
      end
    end
  end

  def sz(t, *args); self.class.sz(t, *args); end
  def self.sz(t, *args)
    begin
      send "sz#{ t }", *args
    rescue => e
      case t.to_s
      when /^strz(\d+)/
        $1.to_i
      when /^strs(\d+)/
        $1.to_i
      when /^str.*/
        raise Exception, "can't take size of unbounded string"
      else
        raise e
      end
    end
  end

  def shraw(n=length)
    ret = ldraw(n)
    consume!
    return ret
  end

  def sh(t, *args)
    return shraw(t) if t.kind_of? Numeric
    ret = send "ld#{ t }", *args
    consume!
    return ret
  end

  def ldsz(n=0)
    n = @content.size - @position if n == 0
    ld(n).unpack("a#{ n }").first
  end

  def ldss(n=0)
    n = @content.size - @position if n == 0
    ld(n).unpack("A#{ n }").first
  end

  def length; @content.length; end
  def size; @content.size; end
  def empty?; @content.empty?; end

  def available; length - position; end
  alias_method :remaining, :available

  def to_s; @content.dup; end
  def ==(b); to_s == b.to_s; end
  def reset; @position = 0; end
  def eof?; @position >= length; end
  def clear!; @content = "" and reset; end
  def remainder(n = position); @content[n..-1] || ""; end
  def remainder_as_buffer(t=Ragweed::Sbuf); t.new(:content => remainder); end

  def self.szl64; 8; end
  def self.szb64; 8; end
  def self.szn64; 8; end

  def ldl64; ld(8).unpack("Q").first; end
  def ldb64; ld(8).reverse.unpack("Q").first; end
  alias_method :ldn64, :ldb64

  def stl64(v); straw([v].pack("Q")); end
  def stb64(v); straw([v].pack("Q").reverse); end
  alias_method :stn64, :stb64

  def self.szl32; 4; end
  def self.szb32; 4; end
  def self.szn32; 4; end

  def ldl32; ld(4).unpack("L").first; end
  def ldb32; ld(4).unpack("N").first; end
  alias_method :ldn32, :ldb32

  def stl32(v); straw([v].pack("L")); end
  def stb32(v); straw([v].pack("N")); end
  alias_method :stn32, :stb32

  def self.szl16; 2; end
  def self.szb16; 2; end
  def self.szn16; 2; end

  def ldl16; ld(2).unpack("v").first; end
  def ldb16; ld(2).unpack("n").first; end
  alias_method :ldn16, :ldb16

  def stl16(v); straw([v].pack("v")); end
  def stb16(v); straw([v].pack("n")); end
  alias_method :stn16, :stb16

  def self.szl8; 1; end;
  def self.szb8; 1; end;
  def self.szn8; 1; end;

  def ldl8; ld(1)[0]; end
  def ldb8; ldl8; end
  alias_method :ldn8, :ldb8

  def stl8(v)
    if v.kind_of? String
      straw(v[0].chr)
    else
      straw([v].pack("c"))
    end
  end

  def stb8(v); stl8(v); end
  alias_method :stn8, :stb8
end
