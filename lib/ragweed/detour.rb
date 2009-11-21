class Ragweed::Detour
  # "Ghetto Detours", as Scott Stender might say. Patch subprograms
  # in to running programs as a hooking mechanism.
  class Detour
    attr_reader :snarfed
    attr_reader :dpoint
    attr_reader :stack

    # Easiest way to do this is just to ask WinProcess#detour. Wants
    # "p" to be a pointer into the process, presumable returned from
    # WinProcess#get_proc.
    # 
    # In theory, "p" should be OK anywhere as long as there are 5
    # bytes of instructions before the end of the basic block its
    # in. In practice, this only really stands a chance of working
    # if "p" points to a function prologue.
    def initialize(p, opts={})      
      @p = p.p
      @dpoint = p
      @opts = opts
      @a = @opts[:arena] || @p.arena
      @stack = @a.alloc(2048)
      @snarfed = snarf_prologue
    end

    # Release the detour and its associated memory, unpatch the
    # target function.
    def release
      @dpoint.write(@snarfed)
      @a.release if not @opts[:arena]
    end

    # Patch the target function. There is a 70% chance this will
    # totally fuck your process. 
    #
    # You would be wise to have the threads in the process suspended
    # while you do this, but I'm not going to do it for you.
    def call
      # a Detours-style trampoline --- the location we patch the
      # target function to jump to --- consists of:
      #
      # - A stack switch (to push/pop w/o fucking the program)
      # - A context save
      # - The Detour code
      # - A context restore
      # - A stack restore
      # - The code we patched out of the target
      # - A jump back to the target function (after the prologue)

      # Do this now to make room for the (probably 5 byte) jump. 
      # We don't know what the address will be until we allocate.
      jumpback = (Jmp 0xDEADBEEF) # patch back later

      # Build the trampoline
      tramp = trampoline(@stack).assemble

      # Figure out how big the whole mess will be, allocate it
      tsz = tramp.size + @snarfed.size + jumpback.to_s.size
      tbuf = @a.alloc(tsz + 10)
      
      # assume trampoline is ahead of the patched program text;
      # jump to [dpoint+patch]
      jumpback.dst = (@dpoint.to_i + @snarfed.size) - (tbuf + tsz)
      
      # Write it into memory. It's not "live" yet because we haven't
      # patched the target function.
      @p.write(tbuf, tramp + @snarfed + jumpback.to_s)

      # But now it is. =)
      @p.write(@dpoint, injection(tbuf).assemRASble)
    end

    # Hook function. Override this in subclasses to provide different
    # behavior.
    def inner_block
      i = Ragweed::Rasm::Subprogram.new
      i.<< Int(3)
    end

    private

    # No user-servicable parts below.

    # Pull at least 5 bytes of instructions out of the prologue, using
    # the disassembler, to make room for our patch jump. Save it, so 
    # we can unpatch later.
    def snarf_prologue
      i = 0
      (buf = @dpoint.read(20)).distorm.each do |insn|
        i += insn.size
        break if i >= 5
      end
      buf[0...i]      
    end

    # Create the Jmp instruction that implements the patch; you can't
    # do this until you know where the trampoline was actually injected
    # into the process.
    def injection(tramp)
      here = @dpoint
      there = tramp

      if there < here
        goto = -((here - there) + 5)
      else
        goto = there - here
      end

      i = Ragweed::Rasm::Subprogram.new
      i.<< Ragweed::Rasm::Jmp(goto.to_i)
    end

    # Create the detours trampoline:
    def trampoline(stack)
      i = Ragweed::Rasm::Subprogram.new
      i.concat push_stack(stack)   # 1. Give us a new stack
      i.concat save_all            # 2. Save all the GPRs just in case
      i.concat inner_block         # 3. The hook function
      i.concat restore_all         # 4. Restore all the GPRs.
      i.concat pop_stack           # 5. Restore the stack
      return i
    end

    # Swap in a new stack, pushing the old stack address 
    # onto the top of it.
    def push_stack(addr, sz=2048)
      i = Ragweed::Rasm::Subprogram.new
      i.<< Ragweed::Rasm::Push(eax)
      i.<< Ragweed::Rasm::Mov(eax, addr+(sz-4))
      i.<< Ragweed::Rasm::Mov([eax], esp)
      i.<< Ragweed::Rasm::Pop(eax)
      i.<< Ragweed::Rasm::Mov(esp, addr+(sz-4))
    end

    # Swap out the new stack.
    def pop_stack
      i = Ragweed::Rasm::Subprogram.new
      i.<< Ragweed::Rasm::Pop(esp)
      i.<< Ragweed::Rasm::Add(esp, 4)
    end

    # Just push all the registers in order
    def save_all
      i = Ragweed::Rasm::Subprogram.new
      [eax,ecx,edx,ebx,ebp,esi,edi].each do |r|
        i.<< Ragweed::Rasm::Push(r)
      end
      i
    end

    # Just pop all the registers
    def restore_all
      i = Ragweed::Rasm::Subprogram.new
      [edi,esi,ebp,ebx,edx,ecx,eax].each do |r|
        i.<< Ragweed::Rasm::Pop(r)
      end
      i
    end    
  end

  # A breakpoint implemented as a Detour. TODO not tested.
  class Dbreak < Detour
    attr_reader :ev1, :ev2 

    # accepts:
    # :ev1:     reuse events from somewhere else 
    # :ev2: 
    def initialize(*args)
      super 
      @ev1 = @opts[:ev1] || WinEvent.new
      @ev2 = @opts[:ev2] || WinEvent.new

      # create the state block that the eventpair shim wants:
      mem = @a.alloc(100)
      @data = mem

      # ghetto vtbl
      swch = ["OpenProcess",                   
              "DuplicateHandle", 
              "ResetEvent", 
              "SetEvent", 
              "WaitForSingleObject",
              "GetCurrentThreadId"].
        map {|x| @p.get_proc("kernel32!#{x}").to_i}.
        pack("LLLLLL")

      # ghetto instance vars
      state = [@p.w.get_current_process_id, @ev1.handle, @ev2.handle].
        pack("LLL")
      @data.write(swch + state)
    end

    def inner_block      
      i = Ragweed::Rasm::Subprogram.new      
      i.<< Push(eax)
      i.<< Xor(eax, eax)
      i.<< Or(eax, @data)
      i.<< Push(eax) 
      i.<< Call(1)            # cheesy in the extreme: fake a call
                              # so I don't have to change my event shim
      i.<< Nop.new
      i.<< Nop.new
      i.<< Nop.new
      i.<< Nop.new
      i.<< Nop.new
      s = event_pair_stub
      s[-1] = Add(esp, 4)
      i.concat(s)
      i.<< Pop(eax)
      return i
    end

    # in theory, loop on this breakpoint
    def on(&block)
      puts "#{ @p.pid }: #{ @ev1.handle }" # in case we need to release
      loop do
        @ev1.wait
        yield 
        @ev2.signal
      end
    end
  end
end
