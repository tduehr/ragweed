#!/usr/bin/env ruby

# This is a slightly more complex hit tracer implementation of
# Debuggerx. It does fork/exec and attempts, in a manner resembling
# rocket surgery with a steamroller, to skip any call to ptrace.

# This was last setup to debug the race condition in Debuggerx#on_breakpoint
# using ftp as the child.

require 'debuggerx'
require 'pp'
require 'rubygems'
require 'ruby-debug'
Debugger.start
include Ragweed

filename = ARGV[0]
pid = ARGV[1].to_i
ptraceloc = 0
rd, wr = nil, nil

class Debuggerx
  attr_accessor :attached

  def on_exit(status)
    pp "Exited with status #{ status }"
    throw(:break)
    @hooked = false
    @attached = false
    @exited = true
  end

  def on_single_step
  end

  def on_sigsegv
    pp "SEGV"
    pp self.threads
    self.threads.each do |t|
      pp self.get_registers(t)
      pp Wrapx::ThreadInfo.get(t)
    end
    debugger
    @exited = true
    throw(:break)
  end

  def on_sigbus
    pp "sigbus"
    pp Wrapx::vm_read(@task,0x420f,169)
    # Kernel.debugger
    # Debugger.breakpoint
    # Debugger.catchpoint
    debugger
    throw(:break)
  end
end

if pid == 0
  rd, wr = IO.pipe
  pid = fork 
end

if pid.nil?
  ptraceloc = Wrapx::LIBS['/usr/lib/libc.dylib'].sym("ptrace", "IIIII").to_ptr.ref.to_s(Wrapx::SIZEOFINT).unpack("I_").first

  pp ptraceloc
  rd.close
  wr.puts ptraceloc

  Wrapx::ptrace(Wrapx::Ptrace::TRACE_ME, 0, 0, 0)
  puts "Traced!"
  # sleep(1)

  puts "Execing"
  exec(ARGV[1])
  puts "it left"
else
  d = Debuggerx.new(pid)

  if rd
    wr.close
    d.attached = true
    ptraceloc = rd.gets.chomp.to_i(0)

    pp ptraceloc.to_s(16)
    pp d
    pp d.threads

    raise "Fail!" if ptraceloc == 0

    d.breakpoint_set(ptraceloc,"Ptrace",(bpl = lambda do |t, r, s|
      puts "#{ s.breakpoints[r.eip].first.function } hit in thread #{ t }\n"
      pp r
      # if Wrapx::dl_bignum_to_ulong(r.esp + 16).to_s(4).unpack("I").first == Wrapx::Ptrace::DENY_ATTACH
        r.eax = 0
        # r.esp = r.ebp
        # r.ebp = Wrapx::vm_read(s.task,r.esp,4).unpack("I_").first
        # r.eip = Wrapx::vm_read(s.task,r.esp+4,4).unpack("I_").first
        # r.esp +=8
        r.eip = Wrapx::vm_read(s.task,r.esp,4).unpack("I_").first
        r.esp+=4
        pp "bounced"
      # else
        pp Wrapx::dl_bignum_to_ulong(r.esp).to_s(5*4).unpack("IIIII")
        pp Wrapx::dl_bignum_to_ulong(r.esp + 16).to_s(4).unpack("I")
      # end
    end))

    d.install_bps

    class Debuggerx    
      def on_sigtrap
        if not @first
          @first = true
          self.install_bps
        end
      end

      def on_stop(signal)
        pp "#Stopped with signal #{ signal } (on_stop)"
      end
    end

  else
    d.attach

    class Debuggerx
      def on_sigstop
        if not @first
          @first = true
          self.install_bps
        end
      end

      def on_stop(signal)
        pp "#Stopped with signal #{ signal } (on_stop)"
      end
    end
  end

  File.open(filename, "r") do |fd|
    lines = fd.readlines
    lines.map {|x| x.chomp!}
    lines.each do |tl|
      pp tl
      fn, addr = tl.split(",", 2)
      pp [fn, addr.to_i(16)]
      if (not addr.nil? and addr.to_i(16) > 0)
        d.breakpoint_set(addr.to_i(16), fn, (bpl = lambda do | t, r, s | 
          puts "#{ s.breakpoints[r.eip].first.function } hit in thread #{ t }\n"
          # pp r
          # debugger
        end))
      end
    end
  end

  blpwd = Wrapx::vm_read(d.task,0x420f,16)
  bbus = Wrapx::vm_read(d.task,0x4220,32)

  catch(:break) { d.loop() }

  if not d.exited
    pp d.threads

    d.threads.each do |t|
      r = Wrapx::ThreadContext.get(t)
      i = Wrapx::ThreadInfo.get(t)
      pp r
      puts r.dump
      pp i
      puts i.dump
    end
  end
end
