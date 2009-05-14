# Cheating; monkeypatching Object is evil.
class Object
  # self-evident
  def callable?; respond_to? :call; end
  def number?; kind_of? Numeric; end

  # while X remains callable, keep calling it to get its value
  def derive
    x = self
    while x.callable?
      x = x()
    end
    return x
  end
end

class String
  # this is just horrible
  def distorm
    Frasm::DistormDecoder.new.decode(self)
  end

  def disasm
    distorm.each {|i| puts i.mnem}
  end
end
