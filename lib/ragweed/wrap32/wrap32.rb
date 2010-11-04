require 'ffi'
require 'ostruct'
require 'Win32API'
require 'pp'

module Ragweed;end
module Ragweed::Wrap32

  NULL = 0x0

  module PagePerms
    EXECUTE = 0x10
    EXECUTE_READ = 0x20
    EXECUTE_READWRITE = 0x40
    EXECUTE_WRITECOPY = 0x80
    NOACCESS = 0x1
    READONLY = 0x2
    READWRITE = 0x4
    WRITECOPY = 0x8

    WRITEABLE = [EXECUTE_READWRITE,
                 EXECUTE_WRITECOPY,
                 READWRITE,
                 WRITECOPY]
  end

  module FileSharing
    NONE = 0
    DELETE = 4
    READ = 1
    WRITE = 2
  end

  module FileDisposition
    CREATE_ALWAYS = 2
    CREATE_NEW = 1
    OPEN_ALWAYS = 4
    OPEN_EXISTING = 3
    TRUNCATE_EXISTING = 5
  end

  module FileAttributes
    ARCHIVE = 0x20
    ENCRYPTED = 0x4000
    HIDDEN = 0x2
    NORMAL = 0x80
    OFFLINE = 0x1000
    READONLY = 1
    SYSTEM = 4
    TEMPORARY = 0x100
    BACKUP = 0x02000000
    DELETE_ON_CLOSE = 0x04000000
    NO_BUFFERING = 0x20000000
    NO_RECALL = 0x00100000
    REPARSE_POINT = 0x00200000
    OVERLAPPED = 0x40000000
    POSIX = 0x0100000
    RANDOM_ACCESS = 0x10000000
    SEQUENTIAL = 0x08000000
    WRITE_THROUGH = 0x80000000
  end

  module FileAccess
    GENERIC_READ = 0x80000000
    GENERIC_WRITE = 0x40000000
    GENERIC_EXECUTE = 0x20000000
    GENERIC_ALL = 0x10000000
  end

  module FormatArgs
    FROM_SYSTEM = 4096
    ALLOCATE_BUFFER = 256
  end

  module Win
    extend FFI::Library

    ffi_lib 'kernel32', 'Advapi32'
    ffi_convention :stdcall
    attach_function 'OpenProcess', [ :long, :long, :long ], :long
    attach_function 'OpenThread', [ :long, :long, :long ], :long
    attach_function 'CloseHandle', [ :long ], :long
    attach_function 'GetLastError', [ ], :long
    attach_function 'FormatMessageA', [ :long, :pointer, :long, :long, :pointer, :long, :pointer ], :void
    attach_function 'VirtualAllocEx', [ :long, :long, :long, :long, :long ], :long
    attach_function 'VirtualFreeEx', [ :long, :long, :long, :long,  ], :long
    attach_function 'WriteProcessMemory', [ :long, :long, :pointer, :long, :long ], :long
    attach_function 'ReadProcessMemory', [ :long, :long, :pointer, :long, :long ], :long
    attach_function 'VirtualQueryEx', [ :long, :long, :pointer, :long ], :long
    attach_function 'VirtualProtectEx', [ :long, :long, :long, :long, :pointer ], :void
    attach_function 'GetCurrentProcessId', [], :long
    attach_function 'GetProcessId', [ :long ], :long
    attach_function 'GetCurrentThreadId', [], :long
    attach_function 'GetModuleHandleA', [ :pointer ], :long
    attach_function 'LoadLibraryA', [ :pointer ], :long
    attach_function 'GetProcAddress', [ :long, :pointer], :long
    attach_function 'WaitForSingleObject', [ :long, :long ], :long
    attach_function 'Process32First', [ :long, :pointer ], :long
    attach_function 'Process32Next', [ :long, :pointer ], :long
    attach_function 'Module32First', [ :long, :pointer ], :long
    attach_function 'Module32Next', [ :long, :pointer ], :long
    attach_function 'CreateToolhelp32Snapshot', [ :long, :long ], :long
    attach_function 'Thread32First', [ :long, :pointer ], :long
    attach_function 'Thread32Next', [ :long, :pointer ], :long
    attach_function 'SuspendThread', [ :long ], :long
    attach_function 'ResumeThread', [ :long ], :long
    attach_function 'CreateRemoteThread', [ :long, :long, :long, :long, :long, :long, :long ], :long
    attach_function 'Sleep', [ :long ], :long
    attach_function 'DuplicateHandle', [ :long, :long, :long, :pointer, :long, :long, :long ], :long
    attach_function 'CreateFileA', [ :pointer, :long, :long, :pointer, :long, :long, :pointer ], :long
    attach_function 'OpenEventA', [ :long, :long, :pointer ], :long
    attach_function 'CreateEventA', [ :long, :long, :long, :pointer ], :long
    attach_function 'SetEvent', [ :long ], :long
    attach_function 'ResetEvent', [ :long ], :long
    attach_function 'WriteFile', [ :long, :pointer, :long, :pointer, :pointer ], :long
    attach_function 'ReadFile', [ :long, :pointer, :long, :pointer, :pointer ], :long
    attach_function 'DeviceIoControl', [ :long, :long, :pointer, :long, :pointer, :long, :pointer, :pointer ], :long
    attach_function 'GetOverlappedResult', [ :long, :pointer, :pointer, :long ], :long
    attach_function 'WaitForMultipleObjects', [ :long, :pointer, :long, :long ], :long

    ffi_lib 'ntdll'
    ffi_convention :stdcall
    attach_function 'NtQueryInformationProcess', [ :long, :long, :pointer, :long, :pointer ], :long

    ffi_lib 'msvcrt'
    ffi_convention :stdcall
    attach_function 'malloc', [ :long ], :long
    attach_function 'memcpy', [ :pointer, :pointer, :long ], :long

    ## XXX This shouldnt be in psapi in win7, need to clean this up
    ## XXX Also the unicode version should be supported, this is NOT complete
    ffi_lib 'psapi'
    ffi_convention :stdcall
    attach_function 'GetMappedFileNameA', [ :long, :long, :pointer, :long ], :long
  end

  class << self

    # Get a process handle given a pid
    def open_process(pid)
      r = Win.OpenProcess(0x1F0FFF, 0, pid)
      raise WinX.new(:open_process) if r == 0
      return r
    end

    # Get a thread handle given a tid; if a block is provided, the semantics are
    # as File#open with a block.
    def open_thread(tid, &block)
      h = Win.OpenThread(0x1F03FF, 0, tid)
      raise WinX.new(:open_thread) if h == 0
      if block_given?
        ret = yield h
        close_handle(h)
        return ret
      end
      h
    end

    # Close any Win32 handle. Reminder: Win32 handles are just integers, like file
    # descriptors in Posix.
    def close_handle(h)
    raise WinX.new(:close_handle) if Win.CloseHandle(h) == 0
    end

    # Get the last error code (errno) (can't fail)
    def get_last_error
      Win.GetLastError()
    end

    # strerror(errno) (can't fail)
    def format_message(code=nil)
      code ||= get_last_error
      buf = FFI::MemoryPointer.from_string("\x00" * 4096)
      Win.FormatMessageA(4096, nil, code, 0x00000400, buf, 4096, nil)
      return buf.to_s.split("\x00")[0]
    end

    # Allocate memory in a remote process (or yourself, with handle -1)
    def virtual_alloc_ex(h, sz, addr=NULL, prot=0x40)
      r = Win.VirtualAllocEx(h, addr, sz, 0x1000, prot)
      raise WinX.new(:virtual_alloc_ex) if r == 0
      return r
    end

    # Free memory in a remote process given the pointer returned from virtual_alloc_ex
    def virtual_free_ex(h, ptr, type=0x8000)
      r = Win.VirtualFreeEx(h, ptr.to_i, 0, type)
      raise WinX.new(:virtual_free_ex) if r == 0
      return r
    end

    # Write a string into the memory of a remote process given its handle and an address
    def write_process_memory(h, dst, val)
      val = val.to_s if not val.kind_of? String
      r = Win.WriteProcessMemory(h, dst.to_i, val, val.size, NULL)
      raise WinX.new(:write_process_memory) if r == 0
      return r
    end

    # Read from a remote process given an address and length, returning a string.
    def read_process_memory(h, ptr, len)
#      val = FFI::MemoryPointer.from_string("\x00" * len)
      val = "\x00" * len
      r = Win.ReadProcessMemory(h, ptr.to_i, val, len, NULL)
      raise WinX.new(:read_process_memory) if r == 0
      return val ## don't handle short reads XXX
    end

    def get_mapped_filename(h, lpv, size)
        val = "\x00" * size
        r = Win.GetMappedFileNameA(h, lpv.to_i, val, size)
        raise WinX.new(:get_mapped_filename) if r == 0
        return val
    end

    def str2memory_basic_info(mbi)
      s = OpenStruct.new
      s.BaseAddress,
      s.AllocationBase,
      s.AllocationProtect,
      s.RegionSize,
      s.State,
      s.Protect,
      s.Type = mbi.unpack("LLLLLLL")
      return s
    end

    # Return a struct with the MEMORY_BASIC_INFORMATION for a given address in the
    # memory of a remote process. Gives you addressable memory ranges and protection
    # flags.
    def virtual_query_ex(h, ptr)
      mbi = [0,0,0,0,0,0,0].pack("LLLLLLL")
      if Win.VirtualQueryEx(h, ptr, mbi, mbi.size)
        str2memory_basic_info(mbi)
      else
        nil
      end
    end

    # Change the protection of specific memory regions in a remote process.
    def virtual_protect_ex(h, addr, prot, size=0)
      old = [0].pack("L")
      base = virtual_query_ex(h, addr).BaseAddress if size == 0
      base ||= addr

      if Win.VirtualProtectEx(h, base, size, prot, old)
        old.unpack("L").first
      else
        raise WinX.new(:virtual_protect_ex)
      end
    end

    # getpid
    def get_current_process_id
      Win.GetCurrentProcessId() # can't realistically fail
    end

    # get_processid
    def get_process_id(h)
      Win.GetProcessId(h)
    end

    # gettid
    def get_current_thread_id
      Win.GetCurrentThreadId() # can't realistically fail
    end

    # Given a DLL name, get a handle to the DLL.
    def get_module_handle(name)
      name = name
      r = Win.GetModuleHandleA(name)
      raise WinX.new(:get_module_handle) if r == 0
      return r
    end

    # load a library explicitly from a dll
    def load_library(name)
      name = name
      r = Win.LoadLibraryA(name)
      raise WinX.new(:load_library) if r == 0
      return r
    end

    # Using notation x = "foo!bar" or x = handle, y = meth, look up a function's
    # address in a module. Note that this is local, not remote.
    def get_proc_address(x, y=nil)
      if not y
        mod, meth = x.split "!"
        h = get_module_handle(mod)
      else
        h = x
        meth = y
      end

      r = Win.GetProcAddress(h, meth)
      return r # pass error through
    end

    # Select(2), for a single object handle.
    def wait_for_single_object(h)
      r = Win.WaitForSingleObject(h, -1)
      raise WinX.new(:wait_for_single_object) if r == -1
    end

    def str2process_info(str)
      ret = OpenStruct.new
      ret.dwSize,
      ret.cntUsage,
      ret.th32ProcessID,
      ret.th32DefaultHeapID,
      ret.th32ModuleID,
      ret.cntThreads,
      ret.th32ParentProcessID,
      ret.pcPriClassBase,
      ret.dwFlags,
      ret.szExeFile = str.unpack("LLLLLLLLLA2048")
      ret.szExeFile = ret.szExeFile.asciiz
      return ret
    end

    # Use Toolhelp32 to enumerate all running processes on the box, returning
    # a struct with PIDs and executable names.
    def all_processes
      h = Win.CreateToolhelp32Snapshot(0x2, 0)
      if h != -1
        pi = [(9*4)+2048,0,0,0,0,0,0,0,0,"\x00"*2048].pack("LLLLLLLLLa2048")
        if Win.Process32First(h, pi) != 0
          yield str2process_info(pi)
          while Win.Process32Next(h, pi) != 0
            yield str2process_info(pi)
          end
        end
      else
        raise WinX.new(:create_toolhelp32_snapshot)
      end
    end

    def str2module_info(str)
      ret = OpenStruct.new
      ret.dwSize,
      ret.th32ModuleID,
      ret.th32ProcessID,
      ret.GlblcntUsage,
      ret.ProccntUsage,
      ret.modBaseAddr,
      ret.modBaseSize,
      ret.hModule,
      ret.szModule,
      ret.szExePath = str.unpack("LLLLLLLLA256A260")
      ret.szModule = ret.szModule.asciiz
      ret.szExePath = ret.szExePath.asciiz
      return ret
    end

    # Given a pid, enumerate the modules loaded into the process, returning base
    # addresses, memory ranges, and the module name.
    def list_modules(pid=0)
      h = Win.CreateToolhelp32Snapshot(0x8, pid)
      if h != -1
        mi = [260+256+(8*4),0,0,0,0,0,0,0,"\x00"*256,"\x00"*260].pack("LLLLLLLLa256a260")
        if Win.Module32First(h, mi) != 0
          yield str2module_info(mi)
          while Win.Module32Next(h, mi) != 0
            yield str2module_info(mi)
          end
        end
      else
        raise WinX.new(:create_toolhelp32_snapshot)
      end
    end

    # Use virtual_query_ex to tell whether an address is writable.
    def writeable?(h, off)
      if (x = virtual_query_ex(h, off))
        return PagePerms::WRITEABLE.member?(x.Protect & 0xFF)
      else
        return false
      end
    end

    # NQIP does a lot of things, the most useful of which are getting the 
    # image name of a running process, and telling whether a debugger is loaded. This
    # interface is Ioctl-style; provide an ordinal and a buffer to pass results through.
    def nt_query_information_process(h, ord, buf)
      lenp = [0].pack("L")
      if Win.NtQueryInformationProcess(h, ord, buf, buf.size, lenp) == 0
        len = lenp.unpack("L").first
        return buf[0..(len-1)]
      end
      nil
    end

    def str2thread_info(str)
      ret = OpenStruct.new
      ret.dwSize,
      ret.cntUsage,
      ret.th32ThreadID,
      ret.th32OwnerProcessID,
      ret.tpBasePri,
      ret.tpDeltaPri,
      ret.thFlags = str.unpack("LLLLLLL")
      return ret
    end

    # List all the threads in a process given its pid, returning a struct containing
    # tids and run state. This is relatively expensive, because it uses Toolhelp32.
    def threads(pid)
      h = Win.CreateToolhelp32Snapshot(0x4, pid)
      if h != -1
        mi = [(7*4),0,0,0,0,0,0].pack("LLLLLLL")
        if Win.Thread32First(h, mi) != 0
          ti = str2thread_info(mi)
          yield str2thread_info(mi) if ti.th32OwnerProcessID == pid
          while Win.Thread32Next(h, mi) != 0
            ti = str2thread_info(mi)
            yield str2thread_info(mi) if ti.th32OwnerProcessID == pid
          end
        end
      else
        raise WinX.new(:create_toolhelp32_snapshot)
      end
    end

    # Suspend a thread given its handle.
    def suspend_thread(h)
      r = Win.SuspendThread(h)
      raise WinX.new(:suspend_thread) if r == 0
      return r
    end

    # Resume a suspended thread, returning nonzero if the thread was suspended,
    # and 0 if it was running.
    def resume_thread(h)
      ResumeThread(h)
    end

    # Create a remote thread in the process, starting at the location
    # "start", with the threadproc argument "arg"
    def create_remote_thread(h, start, arg)
      r = Win.CreateRemoteThread(h, NULL, 0, start.to_i, arg.to_i, 0, 0)
      raise WinX.new(:create_remote_thread) if r == 0
      return r
    end

    def sleep(ms=0)
      Win.Sleep(ms)
    end

    # clone a handle out of another open process (or self, with -1)
    def duplicate_handle(ph, h)
      ret = "\x00\x00\x00\x00"
      r = Win.DuplicateHandle(ph, h, -1, ret, 0, 0, 0x2)
      raise WinX.new(:duplicate_handle) if r == 0
      ret.to_l32
    end

    def create_file(name, opts={})
      opts[:disposition] ||= FileDisposition::OPEN_ALWAYS
      opts[:sharing] ||= FileSharing::READ | FileSharing::WRITE
      opts[:access] ||= FileAccess::GENERIC_ALL
      opts[:flags] ||= 0

      r = Win.CreateFileA(name, opts[:access], opts[:sharing], NULL, opts[:disposition], opts[:flags], NULL)
      raise WinX.new(:create_file) if r == -1
      return r
    end
    
    # i haven't made this work, but named handles are kind of silly anyways
    def open_event(name)
      r = Win.OpenEventA(0, 0, name)
      raise WinX.new(:open_event) if r == 0
      return r
    end

    # signal an event
    def set_event(h)
      r = Win.SetEvent(h)
      raise WinX.new(:set_event) if r == 0
      return r
    end

    # force-unsignal event (waiting on the event handle also does this)
    def reset_event(h)
      r = Win.ResetEvent(h)
      raise WinX.new(:reset_event) if r == 0
      return r
    end

    # create an event, which you can signal and wait on across processes
    def create_event(name=nil, auto=false, signalled=false)
      auto = (1 if auto) || 0
      signalled = (1 if signalled) || 0
      name ||= 0

      r = Win.CreateEventA(0, auto, signalled, name);
      raise WinX.new(:create_event) if r == 0
      return r
    end

    def write_file(h, buf, overlapped=nil)
      if overlapped
        opp = overlapped.to_s
      else
        opp = NULL
      end

      outw = "\x00" * 4
      r = Win.WriteFile(h, buf, buf.size, outw, opp)
      raise WinX.new(:write_file) if r == 0 and get_last_error != 997
      return buf, outw.unpack("L").first
    end

    def read_file(h, count, overlapped=nil)
      if overlapped
        opp = overlapped.to_s
      else
        opp = NULL
      end
      outw = "\x00" * 4
      if not (buf = overlapped.try(:target)) or buf.size < count
        buf = "\x00" * count
        overlapped.target = buf if overlapped
      end

      r = Win.ReadFile(h, buf, count, outw, opp)
      raise WinX.new(:read_file) if r == 0 and get_last_error != 997
      return buf, outw.unpack("L").first
    end

    def device_io_control(h, code, inbuf, outbuf, overlapped=NULL)
      overlapped = overlapped.to_s if overlapped
      outw = "\x00" * 4
      r = Win.DeviceIoControl(h, code, inbuf, inbuf.size, outbuf, outbuf.size, outw, overlapped)
      raise WinX.new(:device_io_control) if r == 0 and get_last_error != 997
      return outw.unpack("L").first
    end

    def get_overlapped_result(h, overlapped)
      overlapped = overlapped.to_s
      outw = "\x00" * 4
      r = Win.GetOverlappedResult(h, overlapped, outw, 0)
      raise WinX.new(:get_overlapped_result) if r == 0
      return outw.unpack("L").first
    end

    # just grab some local memory
    # XXX same as FFI name ?
    def malloc(sz)
      r = Win.malloc(sz)
      raise WinX.new(:malloc) if r == 0
      return r
    end

    def memcpy(dst, src, size)
      Win.memcpy(dst, src, size)
    end

    # Block wrapper for thread suspension
    def with_suspended_thread(tid)
      open_thread(tid) do |h|
        begin
          suspend_thread(h)
          ret = yield h
        ensure
          resume_thread(h)
        end
      end
    end

    def wfmo(handles, ms=100)
      hp = handles.to_ptr
      r = Win.WaitForMultipleObjects(handles.size, hp, 0, ms)
      raise WinX(:wait_for_multiple_objects) if r == 0xFFFFFFFF
      if r < handles.size
        return handles[r]
      else
        return nil
      end
    end
  end
end
