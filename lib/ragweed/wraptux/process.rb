class Ragweed::Process

    include Ragweed
    attr_reader :pid

    def initialize(pid); @pid = pid; end

    ## Read/write ranges of data or fixnums to/from the process by address.
    def read(off, sz=4096)
        a = []
        while off < off+sz
            a.push(Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::PEEK_TEXT, @pid, off, 0))
            return a.pack('L*') if a.last == -1 and FFI.errno != 0
            off+=4
        end
        a.pack('L*')
    end

    ## ptrace sucks, writing 8 or 16 bytes will probably
    ## result in failure unless you PTRACE_POKE first and
    ## get the rest of the original value at the address
    def write(off, data)
        while off < data.size
            Ragweed::Wraptux::ptrace(Ragweed::Wraptux::Ptrace::POKE_TEXT, @pid, off, data[off,4].unpack('L').first)
            off += 4
        end
    end

    def read32(off); read(off, 4).unpack("L").first; end
    def read16(off); read(off, 2).unpack("v").first; end
    def read8(off); read(off, 1)[0]; end
    def write32(off, v); write(off, [v].pack("L")); end
    def write16(off, v); write(off, [v].pack("v")); end
    def write8(off, v); write(off, v.chr); end
end
