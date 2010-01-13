%w[ostruct Win32API pp].each {|x| require x}

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

  # Does 2 things:
  # 1.  Parses a terse notation for Win32 functions: "module!function:args=return",
  #     where "args" and "return" are in String#unpack notation.
  #
  # 2.  Memoizes the Win32API lookup.
  #
  # Returns a callable object implementing the specified call.

  CALLS = Hash.new do |h, str|
    lib = proc = args = ret = nil
    lib, rest = str.split "!"
    proc, rest = rest.split ":"
    args, ret = rest.split("=") if rest
    ret ||= ""
    args ||= []
    raise "need proc" if not proc
    h[str] = Win32API.new(lib, proc, args, ret)
  end

  # --------------------------------------------------------------------------------------

  class << self

    # Get a process handle given a pid
    def open_process(pid)
      r = CALLS["kernel32!OpenProcess:LLL=L"].call(0x1F0FFF, 0, pid)
      raise WinX.new(:open_process) if r == 0
      return r
    end

    # Get a thread handle given a tid; if a block is provided, the semantics are
    # as File#open with a block.
    def open_thread(tid, &block)
      h = CALLS["kernel32!OpenThread:LLL=L"].call(0x1F03FF, 0, tid)
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
      raise WinX.new(:close_handle) if CALLS["kernel32!CloseHandle:L"].call(h) != 0
    end

    # Get the last error code (errno) (can't fail)
    def get_last_error
      CALLS["kernel32!GetLastError:=L"].call
    end

    # strerror(errno) (can't fail)
    def format_message(code=nil)
      code ||= get_last_error
      buf = "\x00" * 4096
      CALLS["kernel32!FormatMessageA:LPLLPLP"].
        call(4096, NULL, code, 0x00000400, buf, 4096, NULL)
      return buf.split("\x00")[0]
    end

    # Allocate memory in a remote process (or yourself, with handle -1)
    def virtual_alloc_ex(h, sz, addr=NULL, prot=0x40)
      r = CALLS["kernel32!VirtualAllocEx:LLLLL=L"].
        call(h, addr, sz, 0x1000, prot)
      raise WinX.new(:virtual_alloc_ex) if r == 0
      return r
    end

    # Free memory in a remote process given the pointer returned from virtual_alloc_ex
    def virtual_free_ex(h, ptr, type=0x8000)
      r = CALLS["kernel32!VirtualFreeEx:LLLL=L"].call(h, ptr.to_i, 0, type)
      raise WinX.new(:virtual_free_ex) if r == 0
      return r
    end

    # Write a string into the memory of a remote process given its handle and an address
    def write_process_memory(h, dst, val)
      val = val.to_s if not val.kind_of? String
      r = CALLS["kernel32!WriteProcessMemory:LLPLL=L"].call(h, dst.to_i, val, val.size, NULL)
      raise WinX.new(:write_process_memory) if r == 0
      return r
    end

    # Read from a remote process given an address and length, returning a string.
    def read_process_memory(h, ptr, len)
      val = "\x00" * len
      r = CALLS["kernel32!ReadProcessMemory:LLPLL=L"].call(h, ptr.to_i, val, len, NULL)
      raise WinX.new(:read_process_memory) if r == 0
      return val ## don't handle short reads XXX
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
      if CALLS["kernel32!VirtualQueryEx:LLPL=L"].call(h, ptr, mbi, mbi.size)
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

      if CALLS["kernel32!VirtualProtectEx:LLLLP=L"].call(h, base, size, prot, old)
        old.unpack("L").first
      else
        raise WinX.new(:virtual_protect_ex)
      end
    end

    # getpid
    def get_current_process_id
      CALLS["kernel32!GetCurrentProcessId:=L"].call # can't realistically fail
    end

    # get_processid
    def get_process_id(h)
      return CALLS["kernel32!GetProcessId:L=L"].call(h)
    end

    # gettid
    def get_current_thread_id
      CALLS["kernel32!GetCurrentThreadId:=L"].call # can't realistically fail
    end

    # Given a DLL name, get a handle to the DLL.
    def get_module_handle(name)
      name = name.to_utf16
      r = CALLS["kernel32!GetModuleHandleW:P=L"].call(name)
      raise WinX.new(:get_module_handle) if r == 0
      return r
    end

    # load a library explicitly from a dll
    def load_library(name)
      name = name.to_utf16
      r = CALLS["kernel32!LoadLibraryW:P=L"].call(name)
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

      r = CALLS["kernel32!GetProcAddress:LP=L"].call(h, meth)
      return r # pass error through
    end

    # Select(2), for a single object handle.
    def wait_for_single_object(h)
      r = CALLS["kernel32!WaitForSingleObject:LL=L"].call(h, -1)
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
      h = CALLS["kernel32!CreateToolhelp32Snapshot:LL=L"].call(0x2, 0)
      if h != -1
        pi = [(9*4)+2048,0,0,0,0,0,0,0,0,"\x00"*2048].pack("LLLLLLLLLa2048")
        if CALLS["kernel32!Process32First:LP=L"].call(h, pi) != 0
          yield str2process_info(pi)
          while CALLS["kernel32!Process32Next:LP=L"].call(h, pi) != 0
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
      h = CALLS["kernel32!CreateToolhelp32Snapshot:LL=L"].call(0x8, pid)
      if h != -1
        mi = [260+256+(8*4),0,0,0,0,0,0,0,"\x00"*256,"\x00"*260].pack("LLLLLLLLa256a260")
        if CALLS["kernel32!Module32First:LP=L"].call(h, mi) != 0
          yield str2module_info(mi)
          while CALLS["kernel32!Module32Next:LP=L"].call(h, mi) != 0
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
      if CALLS["ntdll!NtQueryInformationProcess:LLPLP=L"].call(h, ord, buf, buf.size, lenp) == 0
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
      h = CALLS["kernel32!CreateToolhelp32Snapshot:LL=L"].call(0x4, pid)
      if h != -1
        mi = [(7*4),0,0,0,0,0,0].pack("LLLLLLL")
        if CALLS["kernel32!Thread32First:LP=L"].call(h, mi) != 0
          ti = str2thread_info(mi)
          yield str2thread_info(mi) if ti.th32OwnerProcessID == pid
          while CALLS["kernel32!Thread32Next:LP=L"].call(h, mi) != 0
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
      r = CALLS["kernel32!SuspendThread:L=L"].call(h)
      raise WinX.new(:suspend_thread) if r == 0
      return r
    end

    # Resume a suspended thread, returning nonzero if the thread was suspended,
    # and 0 if it was running.
    def resume_thread(h)
      CALLS["kernel32!ResumeThread:L=L"].call(h)
    end

    # Create a remote thread in the process, starting at the location
    # "start", with the threadproc argument "arg"
    def create_remote_thread(h, start, arg)
      r = CALLS["kernel32!CreateRemoteThread:LLLLLLL=L"].call(h, NULL, 0, start.to_i, arg.to_i, 0, 0)
      raise WinX.new(:create_remote_thread) if r == 0
      return r
    end

    def sleep(ms=0)
      CALLS["kernel32!Sleep:L=L"].call(ms)
    end

    # clone a handle out of another open process (or self, with -1)
    def duplicate_handle(ph, h)
      ret = "\x00\x00\x00\x00"
      r = CALLS["kernel32!DuplicateHandle:LLLPLLL=L"].call(ph, h, -1, ret, 0, 0, 0x2)
      raise WinX.new(:duplicate_handle) if r == 0
      ret.to_l32
    end

    def create_file(name, opts={})
      opts[:disposition] ||= FileDisposition::OPEN_ALWAYS
      opts[:sharing] ||= FileSharing::READ | FileSharing::WRITE
      opts[:access] ||= FileAccess::GENERIC_ALL
      opts[:flags] ||= 0

      r = CALLS["kernel32!CreateFile:PLLPLLP=L"].
        call(name, opts[:access], opts[:sharing], NULL, opts[:disposition], opts[:flags], NULL)
      raise WinX.new(:create_file) if r == -1
      return r
    end
    
    # i haven't made this work, but named handles are kind of silly anyways
    def open_event(name)
      r = CALLS["kernel32!OpenEvent:LLP=L"].call(0, 0, name)
      raise WinX.new(:open_event) if r == 0
      return r
    end

    # signal an event
    def set_event(h)
      r = CALLS["kernel32!SetEvent:L=L"].call(h)
      raise WinX.new(:set_event) if r == 0
      return r
    end

    # force-unsignal event (waiting on the event handle also does this)
    def reset_event(h)
      r = CALLS["kernel32!ResetEvent:L=L"].call(h)
      raise WinX.new(:reset_event) if r == 0
      return r
    end

    # create an event, which you can signal and wait on across processes
    def create_event(name=nil, auto=false, signalled=false)
      auto = (1 if auto) || 0
      signalled = (1 if signalled) || 0
      name ||= 0

      r = CALLS["kernel32!CreateEvent:LLLP=L"].call(0, auto, signalled, name);
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
      r = CALLS["kernel32!WriteFile:LPLPP=L"].call(h, buf, buf.size, outw, opp)
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

      r = CALLS["kernel32!ReadFile:LPLPP=L"].call(h, buf, count, outw, opp)
      raise WinX.new(:read_file) if r == 0 and get_last_error != 997
      return buf, outw.unpack("L").first
    end

    def device_io_control(h, code, inbuf, outbuf, overlapped=NULL)
      overlapped = overlapped.to_s if overlapped
      outw = "\x00" * 4
      r = CALLS["kernel32!DeviceIoControl:LLPLPLPP=L"].
        call(h, code, inbuf, inbuf.size, outbuf, outbuf.size, outw, overlapped)
      raise WinX.new(:device_io_control) if r == 0 and get_last_error != 997
      return outw.unpack("L").first
    end

    def get_overlapped_result(h, overlapped)
      overlapped = overlapped.to_s
      outw = "\x00" * 4
      r = CALLS["kernel32!GetOverlappedResult:LPPL=L"].call(h, overlapped, outw, 0)
      raise WinX.new(:get_overlapped_result) if r == 0
      return outw.unpack("L").first
    end

    # just grab some local memory
    def malloc(sz)
      r = CALLS["msvcrt!malloc:L=L"].call(sz)
      raise WinX.new(:malloc) if r == 0
      return r
    end

    def memcpy(dst, src, size)
      CALLS["msvcrt!memcpy:PPL=L"].call(dst, src, size)
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
      r = CALLS["kernel32!WaitForMultipleObjects:LPLL=L"].call(handles.size, hp, 0, ms)
      raise WinX(:wait_for_multiple_objects) if r == 0xFFFFFFFF
      if r < handles.size
        return handles[r]
      else
        return nil
      end
    end
  end
end
