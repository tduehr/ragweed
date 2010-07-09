class Ragweed::Debugger32
  # Hook function calls
  # nargs is the number of arguments taken by function at ip
  # callable/block is called with ev, ctx, dir (:enter or :leave), and args Array (see examples/hook_notepad.rb)
  # default handler prints arguments
  def hook(ip, nargs, callable=nil, &block)
    callable ||= block || lambda do |ev,ctx,dir,args|
      #puts "#{dir} #{ip.to_s(16) rescue ip.to_s}"
      puts args.map{|a| "%08x" % a}.join(',')
    end

    breakpoint_set(ip) do |ev,ctx|
      nargs = nargs.to_i
      if nargs >= 1
        args = (1..nargs).map {|i| process.read32(ctx.esp + 4*i)}
      end
      retp = process.read32(ctx.esp)
      ## set exit bpoint
      ## We can't always set a leave bp but we
      ## want to support bps for function enter/exit
      ## so we do a little lame trick and & the page
      ## to get an idea of where the page is mapped
      ## Its not %100 accurate, need a better solution
      eip = ctx.eip

      if retp != 0 and retp > (eip & 0xffff0000)
        breakpoint_set(retp) do |ev,ctx|
          callable.call(ev, ctx, :leave, args)
          breakpoint_clear(retp)
        end.install
      end
        callable.call(ev, ctx, :enter, args)
    end
  end
end
