#!/usr/bin/env ruby

## Simple example of attaching to a process and letting it run

require 'pp'
require 'ragweed'
require 'debuggertux'
include Ragweed

pid = Ragweed::Debuggertux.find_by_regex(/gcalctool/)

#begin
	t = Ragweed::Debuggertux.threads(pid)
	puts "Which thread do you want to attach to?"
	t.each do |h| puts h end
	pid = STDIN.gets.chomp.to_i

	d = Ragweed::Debuggertux.new(pid)
	d.attach
	d.continue
	catch(:throw) { d.loop }
#rescue
#	puts "Maybe your PID is wrong?"
#end
