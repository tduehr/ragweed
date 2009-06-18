#!/usr/bin/env ruby

# A simple hittracer to debug and test Debuggerosx.
# FILE is CSV file,address
# PID is the proces id to attach to.

require 'debuggerosx'
require 'pp'
require 'irb'
include Ragweed

filename = ARGV[0]
pid = ARGV[1].to_i

raise "hittracerosx.rb FILE PID" if (ARGV.size < 2 or pid <= 0)

class Debuggerosx
  def on_exit
    exit(1)
  end

  def on_single_step
  end
    
  def on_segv(thread)
    pp self.get_registers(thread)
    pp self.threads
    self.threads.each {|thread| puts Wraposx::ThreadContext.get(thread).dump}
    self.threads.each {|thread| puts Wraposx::ThreadInfo.get(thread).dump}
    throw(:break)
  end
    
  def on_bus(thread)
    throw(:break)
  end
end

d = Debuggerosx.new(pid)
d.attach

File.open(filename, "r") do |fd|
  lines = fd.readlines
  lines.map {|x| x.chomp}
  lines.each do |tl|
    fn, addr = tl.split(",", 2)
    d.breakpoint_set(addr.to_i(16), fn, (bpl = lambda do | t, r, s | puts "#{ s.breakpoints[r.eip].first.function } hit in thread #{ t }\n"; end))
  end
end

d.install_bps
d.continue
catch(:throw) { d.loop }
pp d.wait 1
pp d.threads

d.threads.each do |t|
  r = Wraposx::ThreadContext.get(t)
  i = Wraposx::ThreadInfo.get(t)
  pp r
  puts r.dump
  pp i
  puts i.dump
end
