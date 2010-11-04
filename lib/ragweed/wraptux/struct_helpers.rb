module Ragweed::FFIStructInclude
  if RUBY_VERSION < "1.9"
    def methods regular=true
      super + self.offsets.map{|x| x.first.to_s}
    end
  else
    def methods regular=true
      super + self.offsets.map{|x| x.first}
    end
  end

  def method_missing meth, *args
    super unless self.respond_to? meth
    if meth.to_s =~ /=$/
      self.__send__(:[]=, meth.to_s.gsub(/=$/,'').intern, *args)
    else
      self.__send__(:[], meth, *args)
    end
  end

  def respond_to? meth, include_priv=false
    mth = meth.to_s.gsub(/=$/,'')
    self.offsets.map{|x| x.first.to_s}.include? mth || super
  end
end
