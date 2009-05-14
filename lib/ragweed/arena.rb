class Ragweed::Arena
  # I want 3 lambdas:
  # * "get" should take no arguments and result in the address of a fresh
  #   4k page.
  # * "free" should free any 4k page returned by "get"
  # * "copy" should implement memcpy, copying a string into a 4k page.
  def initialize(get, free, copy)
    @get = get
    @free = free
    @copy = copy
    @pages = []
    @avail = 0
    @off = 0
  end

  private

  def get
    p = @get.call
    @pages << p
    @cur = p
    @avail = 4096
    @off = 0
  end

  public

  # Allocate any size less than 4090 from the arena.
  def alloc(sz)
    raise "can't handle > page size now" if sz > 4090
    get if sz > @avail
    ret = @off
    @off += sz
    round = 4 - (@off % 4)
    if (@off + round) > 4096
      @avail = 0
      @off = 4096
    else
      @off += round
      @avail -= (sz + round)
    end

    return Ptr.new(@cur + ret)
  end

  # Copy a buffer into the arena and return its new address.
  def copy(buf)
    ret = alloc(buf.size)
    @copy.call(ret, buf)
    return ret
  end

  # Release the whole arena all at once.
  def release; @pages.each {|p| @free.call(p)}; end
end
