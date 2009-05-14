require "#{File.dirname(__FILE__)}/../ragweed"
include Ragweed

dbg = Debugger.find_by_regex /notepad/i
raise "notepad not running" if dbg.nil?

dbg.hook('kernel32!CreateFileW', 7) {|e,c,d,a| puts "#{d} CreateFileW for #{dbg.process.read(a[0],512).from_utf16_buffer}"}
dbg.loop
dbg.release
