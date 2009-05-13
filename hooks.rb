class Ragweed::Debugger
  # Hook function calls
  # nargs is the number of arguments taken by function at ip
  # callable/block is called with ev, ctx, dir (:enter or :leave), and args Array (see examples/hook_notepad.rb)
  # default handler prints arguments
  def hook(ip, nargs, callable=nil, &block)
    callable ||= block || lambda do |ev, ctx,dir,args|
      puts "#{dir} #{ip.to_s(16) rescue ip.to_s}"
      puts args.map{|a| "%08x" % a}.join(',')
    end

    breakpoint_set(ip) do |ev,ctx|
      args = (1..nargs).map {|i| process.read32(ctx.esp + 4*i)}
      retp = process.read32(ctx.esp)
      # set exit bpoint
      breakpoint_set(retp) do |ev,ctx|
        callable.call(ev, ctx, :leave, args)
        breakpoint_clear(retp)
      end.install
      callable.call(ev, ctx, :enter, args)
    end
  end
end