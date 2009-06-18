#!/usr/bin/env ruby

# This is a slightly more complex hit tracer implementation of
# Debuggerosx. It does fork/exec and attempts, in a manner resembling
# rocket surgery with a steamroller, to skip any call to ptrace.

# This was last setup to debug the race condition in Debuggerosx#on_breakpoint
# using ftp as the child.

require 'rubygems'
require 'ragweed'
require 'pp'
require 'ruby-debug'
Debugger.start

filename = ARGV[0]
pid = ARGV[1].to_i
ptraceloc = 0
rd, wr = nil, nil

class Snicker < Ragweed::Debuggerosx
  attr_accessor :attached

  def on_exit(status)
    pp "Exited with status #{ status }"
    @hooked = false
    @attached = false
    @exited = true
    throw(:break)
  end

  def on_single_step
  end

  def on_sigsegv
    pp "SEGV"
    pp self.threads
    self.threads.each do |t|
      pp self.get_registers(t)
      pp Ragweed::Wraposx::ThreadInfo.get(t)
    end
    debugger
    @exited = true
    throw(:break)
  end

  def on_sigbus
    pp "sigbus"
    # pp Ragweed::Wraposx::vm_read(@task,0x420f,169)
    # # Kernel.debugger
    # # Debugger.breakpoint
    # # Debugger.catchpoint
    # debugger
    throw(:break)
  end
end

if pid == 0
  rd, wr = IO.pipe
  pid = fork 
end

if pid.nil?
  ptraceloc = Ragweed::Wraposx::LIBS['/usr/lib/libc.dylib'].sym("ptrace", "IIIII").to_ptr.ref.to_s(Ragweed::Wraposx::SIZEOFINT).unpack("I_").first

  pp ptraceloc.to_s(16)
  rd.close
  wr.puts ptraceloc

  Ragweed::Wraposx::ptrace(Ragweed::Wraposx::Ptrace::TRACE_ME, 0, 0, 0)
  puts "Traced!"
  # sleep(1)

  puts "Execing #{ARGV[1]}"
  exec(ARGV[1])
  puts "it left"
else
  d = Snicker.new(pid)

  if rd
    wr.close
    # d.attached = true
    ptraceloc = rd.gets.chomp.to_i(0)

    pp ptraceloc.to_s(16)
    pp d
    pp d.threads

    raise "Fail!" if ptraceloc == 0

    d.breakpoint_set(ptraceloc,"Ptrace",(bpl = lambda do |t, r, s|
      puts "#{ s.breakpoints[r.eip].first.function } hit in thread #{ t }\n"
      pp r
      if Ragweed::Wraposx::vm_read(s.task,r.esp + 4,4).unpack("I").first == Ragweed::Wraposx::Ptrace::DENY_ATTACH
        pp Ragweed::Wraposx::vm_read(s.task,r.esp-28,32).unpack("I_*").map{|x| x.to_s(16)}
        pp Ragweed::Wraposx::vm_read(s.task,r.esp,32).unpack("I_*").map{|x| x.to_s(16)}
        r.eax = 0
        # r.esp = r.ebp
        # r.ebp = Ragweed::Wraposx::vm_read(s.task,r.esp,4).unpack("I_").first
        r.eip = Ragweed::Wraposx::vm_read(s.task,r.esp,4).unpack("V").first
        # r.esp = Ragweed::Wraposx::vm_read(s.task,r.ebp,4).unpack("I_").first
        # r.ebp +=4
        # r.eip = Ragweed::Wraposx::vm_read(s.task,r.esp,4).unpack("I_").first
        # r.esp+=4
        pp "bounced"
        return false
      else
        pp Ragweed::Wraposx::vm_read(s.task,r.esp-28,32).unpack("I_*").map{|x| x.to_s(16)}
        pp Ragweed::Wraposx::vm_read(s.task,r.esp,32).unpack("I_*").map{|x| x.to_s(16)}
        # pp Ragweed::Wraposx::dl_bignum_to_ulong(r.esp).ptr.to_s(4).unpack("I").first.to_s(16)
        # pp Ragweed::Wraposx::dl_bignum_to_ulong(r.esp - 15*4).to_s(4*16).unpack("I*").map{|x| x.to_s(16)}
        # pp Ragweed::Wraposx::dl_bignum_to_ulong(r.esp).to_s(15*4).unpack("I*").map{|x| x.to_s(16)}
        return true
      end
    end))

    d.install_bps

    class Snicker < Ragweed::Debuggerosx    
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

    class Snicker < Ragweed::Debuggerosx
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

  # File.open(filename, "r") do |fd|
  #   lines = fd.readlines
  #   lines.map {|x| x.chomp!}
  #   lines.each do |tl|
  #     pp tl
  #     fn, addr = tl.split(",", 2)
  #     pp [fn, addr.to_i(16)]
  #     if (not addr.nil? and addr.to_i(16) > 0)
  #       d.breakpoint_set(addr.to_i(16), fn, (bpl = lambda do | t, r, s | 
  #         puts "#{ s.breakpoints[r.eip].first.function } hit in thread #{ t }\n"
  #         # pp r
  #         # debugger
  #       end))
  #     end
  #   end
  # end
  # 
  # blpwd = Wraposx::vm_read(d.task,0x420f,16)
  # bbus = Wraposx::vm_read(d.task,0x4220,32)

  catch(:break) { d.loop() }

  if not d.exited
    pp d.threads

    d.threads.each do |t|
      r = Ragweed::Wraposx::ThreadContext.get(t)
      i = Ragweed::Wraposx::ThreadInfo.get(t)
      pp r
      puts r.dump
      pp i
      puts i.dump
    end
  end
end
