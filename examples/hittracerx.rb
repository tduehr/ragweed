#!/usr/bin/env ruby

# A simple hittracer to debug and test Debuggerosx.
# FILE is CSV file,address
# PID is the proces id to attach to.

require 'rubygems'
require 'ragweed'
require 'pp'
require 'irb'
include Ragweed

filename = ARGV[0]
pid = ARGV[1].to_i

raise "hittracerx.rb FILE PID" if (ARGV.size < 2 or pid <= 0)

class HitTracer < Ragweed::Debuggerosx
  attr_accessor :counts
  
  def initialize(*args)
    @counts = Hash.new(0)
    super
  end

  def on_exit
    pp @counts
    exit(1)
  end

  def on_single_step
  end
    
  def on_segv(thread)
    pp self.get_registers(thread)
    pp self.threads
    self.threads.each {|thread| puts self.get_registers(thread).dump}
    self.threads.each {|thread| puts Ragweed::Wraposx::thread_info(thread, Ragweed::Wraposx::ThreadInfo::BASIC_INFO).dump}
    throw(:break)
  end
    
  def on_bus(thread)
    puts "BUS!"
    throw(:break)
  end
end

d = HitTracer.new(pid)
d.attach

puts "attached"

File.open(filename, "r") do |fd|
  fd.each_line do |tl|
    fn, addr = tl.split(",", 2).map{|x| x.strip}
    pp [fn, addr.to_i(16).to_s(16)]
    d.breakpoint_set(addr.to_i(16), fn, (bpl = lambda do | tid, regs, slf |
        puts "#{ slf.breakpoints[regs.eip].first.function } hit in thread #{ tid }\n"
        d.counts[slf.breakpoints[regs.eip].first.function] += 1
      end))
  end
end

puts "breakpoints loaded"

d.install_bps
puts "breakpoints installed"
d.continue
puts "continued"
catch(:throw) { d.loop(nil) }
puts 'thrown'
pp d.wait 1
pp d.threads

d.threads.each do |tid|
  r = d.get_registers(tid)
  i = Wraposx::thread_info(tid, Wraposx::ThreadInfo::BASIC_INFO)
  pp r
  puts r.dump
  pp i
  puts i.dump
end


