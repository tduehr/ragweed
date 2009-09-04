class Ragweed::Trampoline

  # Normally called through WinProcess#remote_call, but, for
  # what it's worth: needs a WinProcess instance and a location,
  # which can be a string module!function or a pointer.
  def initialize(p, loc, opts={})
    @p = p
    @loc = @p.get_proc loc
    @argc = opts[:argc]
    @a = @p.arena
    @mem = @a.alloc(1024)
    @arg_mem = @mem + 512
    @wait = opts[:wait] || true
    @chicken = opts[:chicken] 
    @opts = opts
  end

  # Call the remote function. Returns the 32 bit EAX return value provided
  # by stdcall. 
  def call(*args)
    raise "Insufficient Arguments" if @argc and @argc != args.size
    
    @shim = Ragweed::Blocks::remote_trampoline(args.size, @opts)

    # Won't leak memory.
    @p.arena do |a|
      # 1024 is a SWAG. Divide it in half, one for the trampoline
      # (which is unrolled, because I am lazy and dumb) and the other
      # for the call stack.
      base = @p.ptr(a.alloc(1024))
      
      argm = base + 512
      cur = argm

      # Write the location for the tramp to call
      cur.write(@loc)
      cur += 4

      # Write the function arguments into the call stack.
      (0...args.size).each_backwards do |i|
        if args[i].kind_of? Integer
          val = args[i].to_l32
        elsif args[i].kind_of? String
          stash = a.copy(args[i])
          val = stash.to_l32
        else
          val = args[i].to_s
        end
        cur.write(val)
        cur += 4
      end if args.size.nonzero?

      # Write a placeholder for the return value
      cur.write(0xDEADBEEF.to_l32)

      # Write the tramp
      s = @shim.assemble
      base.write(s)

      th = Ragweed::Wrap32::create_remote_thread(@p.handle, base, argm)
      Ragweed::Wrap32::wait_for_single_object(th) if @wait
      Ragweed::Wrap32::close_handle(th)
      ret = @p.read32(cur)
      if ret == 0xDEADBEEF
        ret = nil
      end
      ret
    end
  end
end

class Trevil
  def initialize(p)
    @p = p
    @ev1, @ev2 = [WinEvent.new, WinEvent.new]
    @a = @p.arena
  end

  def clear!
    @a.release
  end

  def go
    mem = @a.alloc(1024)
    base = @p.ptr(mem)
    data = base + 512
    swch = ["OpenProcess",
            "DuplicateHandle",
            "ResetEvent",
            "SetEvent",
            "WaitForSingleObject"].
      map {|x| @p.get_proc("kernel32!#{x}").to_i}.
      pack("LLLLL")
    state = [Ragweed::Wrap32::get_current_process_id, @ev1.handle, @ev2.handle].
      pack("LLL")

    data.write(swch + state)
    base.write(event_pair_stub(:debug => false).assemble)
    Ragweed::Wrap32::create_remote_thread(@p.handle, base, data)
    @ev1.wait
    @ev2
  end
end
