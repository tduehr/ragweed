class Ragweed::Process
  def handle; @h; end
  attr_reader :pid
  include Ragweed

  def self.find_by_regex(name)
    Ragweed::Wrap32::all_processes do |p|
      if p.szExeFile =~ name
        return self.new(p.th32ProcessID)
      end
    end
  end

  # Get a pointer into the remote process; pointers are just fixnums
  # with a read/write method and a to_s.
  def ptr(x)
    ret = Ragweed::Ptr.new(x)
    ret.p = self
    return ret
  end

  # clone a handle from the remote process to here (to here? tf?)
  def dup_handle(h)
    Ragweed::Wrap32::duplicate_handle(@h, h)
  end

  # look up a process by its name --- but this is in the local process,
  # which is broken --- a heuristic that sometimes works for w32 functions,
  # but probably never otherwise.
  def get_proc(name)
    return Ragweed::Ptr.new(name) if name.kind_of? Numeric or name.kind_of? Ptr
    ptr(Ragweed::Wrap32::get_proc_address(name))
  end

  def is_hex(s)
    s = s.strip

    ## Strip leading 0s and 0x prefix
    while s[0..1] == '0x' or s[0..1] == '00'
        s = s[2..-1]
    end

    o = s

    if s.hex.to_s(16) == o
        return true
    end
        return false
  end

  ## This only gets called for breakpoints in modules
  ## that have just been loaded and detected by a LOAD_DLL
  ## event. It is called from on_load_dll() -> deferred_install()
  def get_deferred_proc_remote(name, handle, dll_base)
    if !name.kind_of?String
        return name
    end

    mod, meth = name.split "!"

    if mod.nil? or meth.nil?
        raise "can not set this breakpoint: #{name}"
    end

    modh = handle

    ## Location is an offset
    if is_hex(meth)
        baseaddr = 0
        modules.each do |m|
            if m.szModule == mod
                break
            end
        end

        ret = dll_base + meth.hex
    else
        ## Location is a symbolic name
        ## Win32 should have successfully loaded the DLL
        ret = remote_call "kernel32!GetProcAddress", modh, meth
    end
    ret
  end

  ## This only gets called for breakpoints
  ## in modules that are already loaded
  def get_proc_remote(name)
    if !name.kind_of?String
        return name
    end

    mod, meth = name.split "!"

    if mod.nil? or meth.nil?
        raise "can not set this breakpoint: #{name}"
    end

#    modh = remote_call "kernel32!GetModuleHandleW", mod.to_utf16
    modh = remote_call "kernel32!GetModuleHandleA", mod
    raise "no such module #{ mod }" if not modh

    ## Location is an offset
    if is_hex(meth)
        baseaddr = 0
        modules.each do |m|
            if m.szModule == mod
                baseaddr = m.modBaseAddr
                break
            end
        end

        ## Somehow the module does not appear to be
        ## loaded. This should have been caught by
        ## Process::is_breakpoint_deferred either way
        ## Process::initialize should catch this return
        if baseaddr == 0 or baseaddr == -1
            return name
        end

        ret = baseaddr + meth.hex
    else
        ## Location is a symbolic name
        ret = remote_call "kernel32!GetProcAddress", modh, meth
    end
    ret
  end

  ## Check if breakpoint location is deferred
  ## This method expects a string 'module!function'
  ## true is the module is not yet loaded
  ## false is the module is loaded
  def is_breakpoint_deferred(ip)
    if !ip.kind_of? String
        return false
    end

    m,f = ip.split('!')

    if f.nil? or m.nil?
        return true
    end

    modules.each do |d|
        if d.szModule.to_s.match(/#{m}/)
            return false
        end
    end
    return true
  end

  ## Look up a process by name or regex, returning an array of all
  ## matching processes, as objects.
  def self.by_name(n)
    n = Regexp.new(n) if not n.kind_of? Regexp
    p = []
    all_processes do |px|
      if px.szExeFile =~ n
        p << self.new(px.th32ProcessID)
      end
    end
    p
  end

  # Just need a PID to get started.
  def initialize(pid) 
    @pid = pid
    @h = Ragweed::Wrap32::open_process(pid)
    @a = arena()
  end

  # Return the EXE name of the process.
  def image
    buf = "\x00" * 256
    if Ragweed::Wrap32::nt_query_information_process(@h, 27, buf)
      buf = buf.from_utf16
      buf = buf[(buf.index("\\"))..-1]
      return buf.asciiz
    end
    nil
  end

  # Return a list of all the threads in the process; relatively
  # expensive, so cache the result.
  def threads(full=false, &block)
    return Ragweed::Wrap32::threads(@pid, &block) if block_given?
    ret = []
    Ragweed::Wrap32::threads(@pid) {|x| ((full) ? ret << x : ret << x.th32ThreadID) }
    return ret
  end

  # Suspend all the threads in the process.
  def suspend_all; threads.each {|x| suspend(x)}; end

  # Resume all the threads in the process. XXX this will not 
  # resume threads with suspend counts greater than 1.
  def resume_all; threads.each {|x| resume(x)}; end

  # Suspend a thread by tid. Technically, this doesn't need to be
  # a method; you can suspend a thread anywhere without a process handle.
  def suspend(tid); Ragweed::Wrap32::open_thread(tid) {|x| Ragweed::Wrap32::suspend_thread(x)}; end

  # Resume a thread by tid.
  def resume(tid); Ragweed::Wrap32::open_thread(tid) {|x| Ragweed::Wrap32::resume_thread(x)}; end

  # List the modules for the process, either yielding a struct for
  # each to a block, or returning a list.
  def modules(&block)
    if block_given?
      Ragweed::Wrap32::list_modules(@pid, &block)
    else
      ret = []
      Ragweed::Wrap32::list_modules(@pid) {|x| ret << x}
      return ret
    end
  end

  # Read/write ranges of data or fixnums to/from the process by address.
  def read(off, sz=4096); Ragweed::Wrap32::read_process_memory(@h, off, sz); end
  def write(off, data); Ragweed::Wrap32::write_process_memory(@h, off, data); end
  def read32(off); read(off, 4).unpack("L").first; end
  def read16(off); read(off, 2).unpack("v").first; end
  def read8(off); read(off, 1)[0]; end      
  def write32(off, v); write(off, [v].pack("L")); end
  def write16(off, v); write(off, [v].pack("v")); end
  def write8(off, v); write(off, v.chr); end
  
  # call a function, by name or address, in the process, using 
  # CreateRemoteThread
  def remote_call(meth, *args)
    loc = meth
    loc = get_proc(loc) if loc.kind_of? String
    loc = Ragweed::Ptr.new loc
    raise "bad proc name" if loc.null?
    t = Trampoline.new(self, loc)
    t.call *args
  end

  # Can I write to this address in the process?
  def writeable?(off); Ragweed::Wrap32::writeable? @h, off; end

  # Use VirtualAllocEx to grab a block of memory in the process. This
  # is expensive, the equivalent of mmap()'ing for each allocation. 
  def syscall_alloc(sz); ptr(Ragweed::Wrap32::virtual_alloc_ex(@h, sz)); end

  # Use arenas, when possible, to quickly allocate memory. The upside
  # is this is very fast. The downside is you can't free the memory
  # without invalidating every allocation you've made prior.
  def alloc(sz, syscall=false) 
    if syscall or sz > 4090
      ret = syscall_alloc(sz)
    else
      ptr(@a.alloc(sz))
    end
  end

  # Free the return value of syscall_alloc. Do NOT use for the return
  # value of alloc.
  def free(off)
    Ragweed::Wrap32::virtual_free_ex(@h, off)
  end

  # Convert an address to "module+10h" notation, when possible.
  def to_modoff(off, force=false)
    if not @modules or force
      @modules = modules.sort {|x,y| x.modBaseAddr <=> y.modBaseAddr}
    end

    @modules.each do |m|
      if off >= m.modBaseAddr and off < (m.modBaseAddr + m.modBaseSize)
        return "#{ m.szModule }+#{ (off - m.modBaseAddr).to_s(16) }h"
      end
    end

    return "#{ off.to_x }h"
  end  

  # Get another allocation arena for this process. Pretty cheap. Given
  # a block, behaves like File#open, disposing of the arena when you're
  # done.
  def arena(&block)
    me = self
    a = Arena.new(lambda {me.syscall_alloc(4096)}, 
                  lambda {|p| me.free(p)},
                  lambda {|dst, src| me.write(dst, src)})
    if block_given?
      ret = yield a
      a.release
      return ret
    end
    a
  end

  # Insert a string anywhere into the memory of the remote process,
  # returning its address, using an arena.
  def insert(buf); @a.copy(buf); end

  # List all memory regions in the remote process by iterating over
  # VirtualQueryEx. With a block, yields MEMORY_BASIC_INFORMATION
  # structs. Without it, returns [baseaddr,size] tuples.
  # 
  # We "index" this list, so that we can refer to memory locations
  # by "region number", which is a Rubycorn-ism and not a Win32-ism.
  # You'll see lots of functions asking for memory indices, and this
  # is what they're referring to.
  def list_memory(&block)
    ret = []
    i = 0
    while (mbi = Ragweed::Wrap32::virtual_query_ex(@h, i))
      break if (not ret.empty? and mbi.BaseAddress == 0)
      if block_given?
        yield mbi
      else
        base = mbi.BaseAddress || 0
        size = mbi.RegionSize || 0
        ret << [base,size] if mbi.State & 0x1000 # MEM_COMMIT
        i = base + size
      end
    end
    ret
  end

  # Human-readable standard output of list_memory. Remember that the
  # index number is important.
  def dump_memory_list
    list_memory.each_with_index {|x,i| puts "#{ i }. #{ x[0].to_s(16) }(#{ x[1] })"}
    true
  end

  # Read an entire memory region into a string by region number.
  def get_memory(i, opts={})
    refresh opts
    read(@memlist[i][0], @memlist[i][1])
  end

  # Print a canonical hexdump of an entire memory region by region number.
  def dump_memory(i, opts={}); get_memory(i, opts).hexdump; end

  # In Python, and maybe Ruby, it was much faster to work on large 
  # memory regions a 4k page at a time, rather than reading the 
  # whole thing into one big string. Scan takes a memory region
  # and yields 4k chunks of it to a block, along with the length
  # of each chunk.
  def scan(i, opts={})
    refresh opts
    memt = @memlist[i]
    if memt[1] > 4096
      0.step(memt[1], 4096) do |i|
        block = (memt[1] - i).cap(4096)
        yield read(memt[0] + i, block), memt[0]+i
      end
    else
      yield read(memt[0], memt[1]), memt[0]
    end
  end

  # Dump thread context, returning a struct that contains things like
  # .Eip and .Eax.
  def thread_context(tid)
    Ragweed::Wrap32::open_thread(tid) do |h|
      Ragweed::Wrap32::get_thread_context(h)
    end
  end

  # Take a region of memory and walk over it in 255-byte samples (less
  # than 255 bytes and you lose accuracy, but you can increase it with
  # the ":window" option), computing entropy for each sample, returning
  # a list of [offset,entropy] tuples.
  def entropy_map(i, opts={})
    ret = []
    startoff = opts[:starting_offset]
    startoff ||= 0
    window = opts[:window] || 255
    scan(i, opts) do |block, soff|
      startoff.stepwith(block.size, window) do |off, len|
        ret << [off, block[off,len].entropy]
      end
    end
    return ret
  end

  # Given a source and destination memory region, scan through "source"
  # looking for properly-aligned U32LE values that would be valid pointers
  # into "destination". The ":range_start" and ":range_end" options
  # constrain what a "valid pointer" into "destination" is.
  def pointers_to(src, dst, opts={})
    refresh opts
    ret = {}
    range = ((opts[:range_start] || @memlist[dst][0])..(opts[:range_stop] || @memlist[dst][0]+@memlist[dst][1]))
    scan(src, opts) do |block, soff|
      0.stepwith(block.size, 4) do |off, len|
        if len == 4
          if range.member? block[off,4].to_l32
            ret[soff + off] = block[off,4].to_l32
          end
        end
      end
    end
    return ret
  end

  # Given a memory region number, do a Unix strings(1) on it. Valid
  # options:
  # :unicode:  you probably always want to set this to "true"
  # :minimum:  how small strings to accept.
  # 
  # Fairly slow.
  def strings_mem(i, opts={})
    ret = []
    opts[:offset] ||= 0
    scan(i) do |block, soff|
      while 1
        off, size = block.nextstring(opts)
        break if not off
        opts[:offset] += (off + size)
        ret << [soff+off, size, block[off,size]]
      end
    end
    ret
  end

  # Given a string key, find it in memory. Very slow. Will read all
  # memory regions, but you can provide ":index_range", which must be
  # a Range object, to constrain which ranges to search through. 
  # Returns a list of structs containing absolute memory locations,
  # the index of the region, and some surrounding context for the 
  # hit.
  def hunt(key, opts={})
    ret = []
    refresh opts
    range = opts[:index_range] || (0..@memlist.size)
    @memlist.each_with_index do |t, i|
      if range.member? i
        if opts[:noisy]
          puts "#{ i }. #{ t[0].to_s(16) } -> #{ (t[0]+t[1]).to_s(16) }"
        end
        scan(i, opts) do |block, soff|
          if (needle = block.index(key))
            r = OpenStruct.new
            r.location = (t[0] + soff + needle)
            r.index = i
            r.context = block
            ret << r
            return ret if opts[:first]
          end
        end
      end
    end
    ret
  end

  private

  def windowize(i, opts={})
    window = opts[:window] || 1024
    if window == :auto
      r = region_range(i)
      window = (r.last - r.first) / 60
    end
    return window
  end

  public

  # Like entropy_map, scan a process and compute adler16 checksums for
  # 1k (or :window) blocks.
  def adler_map(i, opts={})
    refresh opts
    window = windowize(i, opts)
    ret = []
    scan(i, opts) do |block,soff|
      0.stepwith(block.size-1, window) do |off, len|
        if (b = block[off,len])
          ret << b.adler 
        end
      end
    end
    ret
  end

  # If you store the adler map, you've compressed the memory region
  # down to a small series of fixnums, and you can use it with this
  # function to re-check the memory region and see if anything's changing.
  def adler_compare(i, orig, opts={})
    refresh opts
    window = windowize(i, opts)
    ret = []
    c = -1
    scan(i, opts) do |block,soff|
      0.stepwith(block.size-1, window) do |off, len|
        if block[off,len].adler != orig[c += 1]
          ret << soff+off
        end
      end
    end
    ret 
  end

  # Quick and dirty visualization of a memory region by checksum
  # changes. 
  class AdlerChart

    # Create with a WinProcess and region index
    def initialize(p, i)
      @p = p
      @i = i
      @initstate = map
    end

    private
    def map; @p.adler_map(@i, :window => :auto); end

    public

    # Just puts the chart repeatedly, to get:
    # ........................................................*.*..
    # ..........................................................*..
    # ..........................................................*..
    # Where * represents a chunk of memory that has changed.
    def to_s
      s = StringIO.new
      newstate = map
      @initstate.each_with_index do |sum, i|
        if sum != newstate[i]
          s.write "*"
          @initstate[i] = newstate[i]
        else
          s.write "."
        end
      end
      s.rewind;s.read()
    end
  end
  
  # See WinProcess::AdlerChart. Get one.
  def adler_chart(i)
    AdlerChart.new self, i
  end

  # Given a memory region, use the adler routines to create a checksum
  # map, wait a short period of time, and scan for changes, to find 
  # churning memory. 
  def changes(i, sleeptime=0.5)
    q = adler_map(i)
    sleep(sleeptime)
    adler_compare(i, q)
  end

  # Get the memory range, as a Ruby Range, for a region by index
  def region_range(i, opts={})
    refresh opts
    (@memlist[i][0]..(@memlist[i][1]+@memlist[i][0]))
  end

  # Figure out what region (by region index) has an address
  def which_region_has?(addr, opts={})
    refresh opts
    @memlist.each_with_index do |r, i|
      return i if (r[0]..r[0]+r[1]).member? addr
    end
    return nil
  end

  # Do something with a thread while its suspended
  def with_suspended_thread(tid)
    ret = nil
    Ragweed::Wrap32::with_suspended_thread(tid) {|x| ret = yield}
    return ret
  end

  # For libraries compiled with frame pointers: walk EBP back
  # until it stops giving intelligible addresses, and, at each
  # step, grab the saved EIP from just before it.
  def thread_stack_trace(tid)
    with_suspended_thread(tid) do
      ctx = thread_context(tid)
      if((start = read32(ctx.Ebp)) != 0) 
        a = start
        stack = [[start, read32(start+4)]]
        while((a = read32(a)) and a != 0 and not stack.member?(a))
          begin
            stack << [a, read32(a+4)]
          rescue; break; end
        end
        return stack
      end
    end
    []
  end

  # Human-readable version of thread_stack_trace, with module
  # offsets. 
  def dump_stack_trace(tid)
    thread_stack_trace(tid).each do |frame, code|
      puts "#{ frame.to_x } @ #{ to_modoff(code) }"
    end
  end
  alias_method :bt, :dump_stack_trace

  def detour(loc, o={})
    klass = o[:class] || Detour
    loc = get_proc(loc)
    r = klass.new(loc, o)
    r.call if not o[:chicken]
    return r
  end

  private

  def refresh(opts={})
    @memlist = list_memory if not @memlist or opts.delete(:refresh)
  end
end 
