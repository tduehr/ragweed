module Ragweed
  class Device
    def initialize(path, options={})
      @path = path
      @options = options
      @h = Wrap32::create_file(@path, :flags => Wrap32::FileAttributes::OVERLAPPED|Wrap32::FileAttributes::NORMAL)
    end

    def ioctl(code, inbuf, outbuf)
      overlap(lambda do |o|
        Wrap32::device_io_control(@h, code, inbuf, outbuf, o)
      end) do |ret, count|
        outbuf[0..count]
      end  
    end
    
    def read(sz)
      overlap(lambda do |o|
        Wrap32::read_file(@h, sz, o)
      end) do |ret, count|
        ret[0..count]
      end
    end
    
    def write(buf)
      overlap(lambda do |o|
        Wrap32::write_file(@h, buf, o)
      end) do |ret, count|
        count
      end
    end 
    
    def release
      Wrap32::close_handle(@h)
      @h = nil
    end

    private

    def overlap(proc)
      o = Wrap32::Overlapped.get
      ret = proc.call(o)
      count = o.wait(@h)
      r = yield ret, count
      o.release
      ret = r if r
    end
  end
end
