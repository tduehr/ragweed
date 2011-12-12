require 'ffi'

module Ragweed::Wraptux
  module Libc
    extend FFI::Library
    ffi_lib FFI::Library::LIBC
    attach_function 'ptrace', [ :ulong, :pid_t, :ulong, :ulong ], :long
    attach_function 'wait', [ :pointer ], :int
    attach_function 'waitpid', [ :int, :pointer, :int ], :int
    attach_function 'kill', [ :int, :int ], :int
    attach_function 'malloc', [ :size_t ], :pointer
    attach_function 'free', [ :pointer ], :void
    attach_function 'execv', [ :pointer, :pointer ], :int
  end
  
  class PTRegs < FFI::Struct
      include Ragweed::FFIStructInclude
      layout :ebx, :ulong,
      :ecx, :ulong,
      :edx, :ulong,
      :esi, :ulong,
      :edi, :ulong,
      :ebp, :ulong,
      :eax, :ulong,
      :xds, :ulong,
      :xes, :ulong,
      :xfs, :ulong,
      :xgs, :ulong,
      :orig_eax, :ulong,
      :eip, :ulong,
      :xcs, :ulong,
      :eflags, :ulong,
      :esp, :ulong,
      :xss, :ulong
  end

  class << self
    # pid_t wait(int *status);
    def wait
      stat = FFI::MemoryPointer.new(:int, 1)
      FFI.errno = 0
      pid = Libc.wait stat
      raise SystemCallError.new "wait", FFI.errno if pid == -1
      [pid, stat.read_pointer.get_int32]
    end
    
    # pid_t waitpid(pid_t pid, int *status, int options);
    def waitpid pid, opts = 0
      p = FFI::MemoryPointer.new(:int, 1)
      FFI.errno = 0
      r = Libc.waitpid(pid,p,opts)
      raise SystemCallError.new "waitpid", FFI.errno if r == -1
      status = p.get_int32(0)
      [r, status]
    end

    # int kill(pid_t pid, int sig);
    def kill pid, sig
      FFI.errno = 0
      r = Libc.kill pid, sig
      raise SystemCallError.new "waitpid", FFI.errno if r == -1
      r
    end
    
    #long ptrace(enum __ptrace_request request, pid_t pid, void *addr, void *data);
    def ptrace req, pid, addr, data
      FFI.errno = 0
      r = Libc.ptrace req, pid, addr, data
      #raise SystemCallError.new "ptrace", FFI.errno if r == -1 and !FFI.errno.zero?
      r
    end
    
    # int execv(const char *path, char *const argv[]);
    def execv(path, *args)
      FFI.errno = 0
      args.flatten!
      argv = FFI::MemoryPointer.new(:pointer, args.size + 2)
      argv[0].put_pointer(0, FFI::MemoryPointer.from_string(path.to_s))
      args.each_with_index do |arg, i|
        argv[i + 1].put_pointer(0, FFI::MemoryPointer.from_string(arg.to_s))
      end
      argv[args.size + 1].put_pointer(0, nil)

      Libc.execv(path, argv)
      # if this returns, an error has occured
      raise SystemCallError :execv, FFI.errno
    end
  end
end
