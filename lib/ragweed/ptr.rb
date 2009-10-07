# TODO: make read/write work for other oses

class Ragweed::Ptr
  # A dubious achievement. Wrap Integers in a pointer class, which,
  # when you call to_s, returns the marshalled type, and which exports
  # read/write methods.
  attr_accessor :p
  attr_reader :val

  # ptr-to-zero?
  def null?
    @val == 0
  end

  # initialize with a number or another pointer (implements copy-ctor)
  def initialize(i)
    if i.kind_of? self.class
      @val = i.val
      @p = i.p
    elsif not i
      @val = 0
    else
      @val = i
    end
  end

  # return the raw pointer bits
  def to_s; @val.to_l32; end

  # return the underlying number
  def to_i; @val; end

  # only works if you attach a process 
  def write(arg); p.write(self, arg); end
  def read(sz); p.read(self, sz); end

  # everything else: work like an integer --- also, where these
  # calls return numbers, turn them back into pointers, so pointer
  # math doesn't shed the class wrapper
  def method_missing(meth, *args) 
    ret = @val.send meth, *args
    if ret.kind_of? Numeric
      ret = Ptr.new(ret)
      ret.p = self.p
    end
    ret
  end
end
