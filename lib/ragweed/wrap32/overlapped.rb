class Ragweed::Wrap32::Overlapped
  attr_accessor :internal
  attr_accessor :internal_high
  attr_accessor :offset
  attr_accessor :offset_high
  attr_accessor :event
  attr_accessor :target

  def self.get
    h = Ragweed::Wrap32::create_event(nil, false, true)
    r = self.new
    r.event = h
    return r
  end

  def initialize(str=nil)
    @buf = "\x00" * 20
    @internal, @internal_high, @offset, @offset_high, @event = [0,0,0,0,0]
    init(str) if str    
  end

  def to_s
    buf = [@internal, @internal_high, @offset, @offset_high, @event].pack("LLLLL")
    @buf.replace(buf)
  end

  def release
    Ragweed::Wrap32::close_handle(@event)
  end

  def wait(h)
    return if not @event
    Ragweed::Wrap32::wait_for_single_object(@event)
    Ragweed::Wrap32::get_overlapped_result(h, self)
  end

  private

  def init(str)
    @internal,
    @internal_high,
    @offset,
    @offset_high,
    @event = str.unpack("LLLLL")
  end
end
