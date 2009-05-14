%w[ostruct Win32API pp].each {|x| require x}

module Ragweed;end
module Ragweed::Wrap32
  class WinX < StandardError
    attr_reader :code
    attr_reader :msg
    attr_reader :call
    def initialize(sym=nil)
      @call = sym 
      @code = Ragweed::Wrap32::get_last_error()
      @msg = "#{(@call ? @call.to_s + ": " : "")}(#{@code}) #{ Ragweed::Wrap32::format_message(@code) }"
      super @msg
    end
  end
end
