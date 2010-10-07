require 'ffi'
module Ragweed::Wraptux
    extend FFI::Library
    ffi_lib FFI::Library::LIBC
    attach_function 'ptrace', [ :ulong, :pid_t, :ulong, :ulong ], :long
    attach_function 'wait', [ :int ], :int
    attach_function 'waitpid', [ :int, :pointer, :int ], :int
    attach_function 'kill', [ :int, :int ], :int
    attach_function 'malloc', [ :size_t ], :pointer
    attach_function 'free', [ :pointer ], :void
end

class PTRegs < FFI::Struct
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
