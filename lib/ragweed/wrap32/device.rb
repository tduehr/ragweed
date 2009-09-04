module Ragweed
  class Device
    def initialize(path, options={})
      @path = path
      @options = options
      @h = Ragweed::Wrap32::create_file(@path, :flags => Ragweed::Wrap32::FileAttributes::OVERLAPPED|Ragweed::Wrap32::FileAttributes::NORMAL)
    end

    def ioctl(code, inbuf, outbuf)
      overlap(lambda do |o|
        Ragweed::Wrap32::device_io_control(@h, code, inbuf, outbuf, o)
      end) do |ret, count|
        outbuf[0..count]
      end  
    end
    
    def read(sz)
      overlap(lambda do |o|
        Ragweed::Wrap32::read_file(@h, sz, o)
      end) do |ret, count|
        ret[0..count]
      end
    end
    
    def write(buf)
      overlap(lambda do |o|
        Ragweed::Wrap32::write_file(@h, buf, o)
      end) do |ret, count|
        count
      end
    end 
    
    def release
      Ragweed::Wrap32::close_handle(@h)
      @h = nil
    end

    private

    def overlap(proc)
      o = Ragweed::Wrap32::Overlapped.get
      ret = proc.call(o)
      count = o.wait(@h)
      r = yield ret, count
      o.release
      ret = r if r
    end
  end
end
