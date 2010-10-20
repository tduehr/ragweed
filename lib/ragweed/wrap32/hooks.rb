class Ragweed::Debugger32
  # Hook function calls
  # nargs is the number of arguments taken by function at ip
  # callable/block is called with ev, ctx, dir (:enter or :leave), and args Array (see examples/hook_notepad.rb)
  # default handler prints arguments
  def hook(ip, nargs, callable=nil, &block)

    callable ||= block || lambda do |ev,ctx,dir,args|
      #puts args.map{|a| "%08x" % a}.join(',')
    end

    breakpoint_set(ip) do |ev,ctx|
      esp = process.read32(ctx[:esp])
      nargs = nargs.to_i

      if nargs >= 1
        args = (1..nargs).map {|i| process.read32(ctx[:esp] + 4*i)}
      end

      ## set exit bpoint
      ## We cant always set a leave bp due to
      ## calling conventions but we can avoid
      ## a crash by setting a breakpoint on
      ## the wrong address. So we attempt to
      ## get an idea of where the instruction
      ## is mapped.
      eip = ctx[:eip]
      if esp != 0 and esp > (eip & 0xf0000000)
        breakpoint_set(esp) do |ev,ctx|
          callable.call(ev, ctx, :leave, args)
          breakpoint_clear(esp)
        end.install
      end

      ## Call the block sent to hook()
      callable.call(ev, ctx, :enter, args)
    end
  end
end
