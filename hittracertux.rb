#!/usr/bin/env ruby

require 'debuggertux'
require 'pp'
require 'irb'
include Ragweed

filename = ARGV[0]
pid = ARGV[1].to_i

raise "hittracertux.rb FILE PID" if (ARGV.size < 2 or pid <= 0)

d = Debuggertux.new(pid)
d.attach

File.open(filename, "r") do |fd|
  lines = fd.readlines
  lines.map {|x| x.chomp}
  lines.each do |tl|
    fn, addr = tl.split(",", 2)
    d.breakpoint_set(addr.to_i(16), fn, (bpl = lambda do puts "hit - #{fn} #{addr}\n"; end))
  end
end

d.install_bps
d.continue
catch(:throw) { d.loop }


# An IDC script for generating the text file this hit tracer requires
=begin
#include <idc.idc>

static main()
{
  auto entry, fname, outf, fd;
  outf = AskFile(1, "*.txt", "Please select an output file");
  fd = fopen(outf,"w");
   
	for(entry=NextFunction(0); entry  != BADADDR; entry=NextFunction(entry) )
	{
		fname = GetFunctionName(entry);
		fprintf(fd, "%s,0x%x\n", fname, entry);
 	}

  fclose(fd);
}
=end
