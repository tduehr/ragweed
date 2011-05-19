require 'ffi'

module Ragweed; end
module Ragweed::Wraposx

  module Libc
    extend FFI::Library
    ffi_lib FFI::Library::LIBC
    typedef :int, :kern_return_t

    typedef :ulong_long, :memory_object_offset_t
    typedef :uint, :vm_inherit_t
    typedef :uint, :natural_t
    typedef :natural_t, :mach_msg_type_number_t
    typedef :natural_t, :mach_port_name_t
    typedef :mach_port_name_t, :mach_port_t
    typedef :mach_port_t, :vm_map_t
    typedef :mach_port_t, :task_t
    typedef :mach_port_t, :thread_act_t
    typedef :int, :vm_region_flavor_t
    typedef :int, :vm_prot_t
    typedef :int, :vm_behavior_t
    typedef :int, :policy_t
    typedef :int, :boolean_t
    typedef :int, :thread_state_flavor_t
    case FFI::Platform::LONG_SIZE
    when 64
      # ifdef __LP64__
      typedef :uintptr_t, :vm_size_t
      typedef :uintptr_t, :vm_offset_t
    when 32
      # else   /* __LP64__ */
      typedef :natural_t, :vm_size_t
      typedef :natural_t, :vm_offset_t
    else
      raise "Unsupported Platform"
    end
    
    typedef :vm_offset_t, :vm_address_t
    
    attach_function :getpid, [], :pid_t
    attach_function :ptrace, [:int, :pid_t, :ulong, :int], :int
    attach_function :wait, [:pointer], :pid_t
    attach_function :waitpid, [:pid_t, :pointer, :int], :pid_t
    attach_function :mach_task_self, [], :mach_port_t
    attach_function :task_for_pid, [:mach_port_name_t, :int, :pointer], :kern_return_t
    attach_function :task_threads, [:task_t, :pointer, :pointer], :kern_return_t
    attach_function :kill, [:pid_t, :int], :int
    attach_function :vm_read_overwrite, [:vm_map_t, :vm_address_t, :vm_size_t, :vm_address_t, :pointer], :kern_return_t
    attach_function :vm_write, [:vm_map_t, :vm_address_t, :vm_offset_t, :mach_msg_type_number_t], :kern_return_t
    attach_function :vm_protect, [:vm_map_t, :vm_address_t, :vm_size_t, :boolean_t, :vm_prot_t], :kern_return_t
    attach_function :vm_allocate, [:vm_map_t, :pointer, :vm_size_t, :int], :kern_return_t
    attach_function :vm_deallocate, [:vm_map_t, :vm_address_t, :vm_size_t], :kern_return_t
    attach_function :thread_resume, [:thread_act_t], :kern_return_t
    attach_function :thread_suspend, [:thread_act_t], :kern_return_t
    attach_function :task_suspend, [:int], :kern_return_t
    attach_function :task_resume, [:int], :kern_return_t
    attach_function :sysctl, [:pointer, :int, :pointer, :pointer, :pointer, :int], :int
    attach_function :execv, [:string, :pointer], :int
  end

  class << self

    # pid_t
    # getpid(void);
    #
    # see also getpid(2)
    def getpid
      Libc.getpid
    end

    # Apple's ptrace is fairly gimped. The memory read and write functionality has been
    # removed. We will be using mach kernel calls for that. see vm_read and vm_write.
    # for details on ptrace and the process for the Wraposx/debuggerosx port see:
    # http://www.matasano.com/log/1100/what-ive-been-doing-on-my-summer-vacation-or-it-has-to-work-otherwise-gdb-wouldnt/
    #
    #int
    #ptrace(int request, pid_t pid, caddr_t addr, int data);
    #
    # see also ptrace(2)
    def ptrace(request, pid, addr, data)
      FFI.errno = 0
      r = Libc.ptrace(request, pid, addr, data)
      raise SystemCallError.new("ptrace", FFI.errno) if r == -1 and FFI.errno != 0
      [r, data]
    end

    # ptrace(PT_TRACE_ME, ...)
    def pt_trace_me pid
      ptrace(Ragweed::Wraposx::Ptrace::TRACE_ME, pid, nil, nil).first
    end

    # ptrace(PT_DENY_ATTACH, ... )
    def pt_deny_attach pid
      ptrace(Ragweed::Wraposx::Ptrace::DENY_ATTACH, pid, nil, nil).first
    end

    # ptrace(PT_CONTINUE, pid, addr, signal)
    def pt_continue pid, addr = 1, sig = 0
      ptrace(Ragweed::Wraposx::Ptrace::CONTINUE, pid, addr, sig).first
    end

    # ptrace(PT_STEP, pid, addr, signal)
    def pt_step pid, addr = 1, sig = 0
      ptrace(Ragweed::Wraposx::Ptrace::STEP, pid, addr, sig).first
    end

    # ptrace(PT_KILL, ... )
    def pt_kill pid
      ptrace(Ragweed::Wraposx::Ptrace::KILL, pid, nil, nil).first
    end

    # ptrace(PT_ATTACH, ... )
    def pt_attach pid
      ptrace(Ragweed::Wraposx::Ptrace::ATTACH, pid, nil, nil).first
    end

    # ptrace(PT_DETACH, ... )
    def pt_detach pid
      ptrace(Ragweed::Wraposx::Ptrace::DETACH, pid, nil, nil).first
    end

    # Originally coded for use in debuggerosx but I've switched to waitpid for 
    # usability and debugging purposes.
    #
    # Returns status of child when child recieves a signal.
    #
    # pid_t
    # wait(int *stat_loc);
    #
    # see also wait(2)
    def wait
      stat = FFI::MemoryPointer.new :int, 1
      FFI.errno = 0
      pid = Libc.wait stat
      raise SystemCallError.new "wait", FFI.errno if pid == -1
      [pid, stat.read_int]
    end

    # The wait used in debuggerosx.
    # opt is an OR of the options to be used.
    #
    # Returns an array. The first element is the pid of the child process
    # as returned by the waitpid system call. The second, the status as
    # an integer of that pid.
    #
    # pid_t
    # waitpid(pid_t pid, int *stat_loc, int options);
    #
    # see also wait(2)
    def waitpid pid, opts = 0
      stat = FFI::MemoryPointer.new :int, 1
      FFI.errno = 0
      r = Libc.waitpid(pid, stat, opts)
      raise SystemCallError.new "waitpid", FFI.errno if r == -1
      [r, stat.read_int]
    end

    # From docs at http://web.mit.edu/darwin/src/modules/xnu/osfmk/man/mach_task_self.html
    # Returns send rights to the task's kernel port.
    #
    # mach_port_t
    # mach_task_self(void)
    #
    # There is no man page for this call.
    def mach_task_self
      Libc.mach_task_self
    end
    
    # Requires sudo to use as of 10.5 or 10.4.11(ish)
    # Returns the task id for a process.
    #
    # kern_return_t task_for_pid(
    #                           mach_port_name_t target_tport,
    #                           int pid,
    #                           mach_port_name_t *t);
    #
    # There is no man page for this call.
    def task_for_pid(pid, target=nil)
      target ||= mach_task_self
      port = FFI::MemoryPointer.new :uint, 1
      r = Libc.task_for_pid(target, pid, port)
      raise KernelCallError.new(:task_for_pid, r) if r != 0
      port.read_uint
    end  

    # Returns an Array of thread IDs for the given task
    #
    # kern_return_t   task_threads
    #                (task_t                                    task,
    #                 thread_act_port_array_t            thread_list,
    #                 mach_msg_type_number_t*           thread_count);
    #
    #There is no man page for this funtion.    
    def task_threads(port)
      threads = FFI::MemoryPointer.new :pointer, 1
      count = FFI::MemoryPointer.new :int, 1
      r = Libc.task_threads(port, threads, count)
      raise KernelCallError.new(:task_threads, r) if r != 0
      threads.read_pointer.read_array_of_uint(count.read_uint)
    end

    # Decrement the target tasks suspend count
    # kern_return_t   task_resume
    #                 (task_t          task);
    def task_resume(task)
      r = Libc.task_resume(task)
      raise KernelCallError.new(r) if r != 0
      r
    end

    # Increment the target tasks suspend count
    # kern_return_t   task_suspend
    #                 (task_t          task);
    def task_suspend(task)
      r = Libc.task_suspend(task)
      raise KernelCallError.new(r) if r != 0
      r
    end

    # Sends a signal to a process
    #
    # int
    # kill(pid_t pid, int sig);
    #
    # See kill(2)
    def kill(pid, sig)
      FFI::errno = 0
      r = Libc.kill(pid, sig)
      raise SystemCallError.new "kill", FFI::errno if r != 0
      r
    end

    # Reads sz bytes from task's address space starting at addr.
    #
    # kern_return_t   vm_read_overwrite
    #                (vm_task_t                           target_task,
    #                 vm_address_t                        address,
    #                 vm_size_t                           size,
    #                 vm_address_t                        *data_out,
    #                 mach_msg_type_number_t              *data_size);
    #
    # There is no man page for this function.
    def vm_read(task, addr, sz=256)
      buf = FFI::MemoryPointer.new(sz)
      len = FFI::MemoryPointer.new(:uint).write_uint(sz)
      r = Libc.vm_read_overwrite(task, addr, sz, buf, len)
      raise KernelCallError.new(:vm_read, r) if r != 0
      buf.read_string(len.read_uint)
    end

    # Writes val to task's memory space at address addr.
    # It is necessary for val.size to report the size of val in bytes
    #
    # kern_return_t   vm_write
    #                (vm_task_t                          target_task,
    #                 vm_address_t                           address,
    #                 pointer_t                                 data,
    #                 mach_msg_type_number_t              data_count);
    #
    # There is no man page for this function.
    def vm_write(task, addr, val)
      val = FFI::MemoryPointer.new(val)
      r = Libc.vm_write(task, addr, val, val.size)
      raise KernelCallError.new(:vm_write, r) if r != 0
      r
    end

    # Changes the protection state beginning at addr for size bytes to the mask prot.
    # If setmax is true this will set the maximum permissions, otherwise it will set FIXME
    #
    # kern_return_t   vm_protect
    #                 (vm_task_t           target_task,
    #                  vm_address_t            address,
    #                  vm_size_t                  size,
    #                  boolean_t           set_maximum,
    #                  vm_prot_t        new_protection);
    #
    # There is no man page for this function.
    def vm_protect(task, addr, size, setmax, prot)
      setmax = setmax ? 1 : 0
      r = Libc.vm_protect(task, addr, size, setmax, prot)
      raise KernelCallError.new(:vm_protect, r) if r != 0
      r
    end

    # Allocates a page in the memory space of the target task.
    #
    # kern_return_t   vm_allocate
    #                 (vm_task_t                          target_task,
    #                  vm_address_t                           address,
    #                  vm_size_t                                 size,
    #                  boolean_t                             anywhere);
    #
    def vm_allocate(task, address, size, anywhere)
      addr = FFI::MemoryPointer.new :int, 1
      addr.write_int(address)
      anywhere = anywhere ? 1 : 0
      r = Libc.vm_allocate(task, addr, size, anywhere)
      raise KernelCallError.new(r) if r != 0
      addr.address
    end

    # deallocates a page in the memoryspace of target task.
    #
    # kern_return_t   vm_deallocate
    #                     (vm_task_t                          target_task,
    #                      vm_address_t                           address,
    #                      vm_size_t                                 size);
    #
    def vm_deallocate(task, address, size)
      addr = FFI::MemoryPointer.new :int, 1
      addr.write_int(address)
      r = Libc.vm_deallocate(task, addr, size)
      raise KernelCallError.new(r) if r != 0
      r
    end

    # Resumes a suspended thread by id.
    #
    # kern_return_t   thread_resume
    #                (thread_act_t                     target_thread);
    #
    # There is no man page for this function.
    def thread_resume(thread)
      r = Libc.thread_resume(thread)
      raise KernelCallError.new(:thread_resume, r) if r != 0
      r
    end

    # Suspends a thread by id.
    #
    # kern_return_t   thread_suspend
    #                (thread_act_t                     target_thread);
    #
    # There is no man page for this function.
    def thread_suspend(thread)
      r = Libc.thread_suspend(thread)
      raise KernelCallError.new(:thread_suspend, r) if r != 0
      r
    end

    # Changes execution to file in path with *args as though called from command line.
    #
    # int
    # execv(const char *path, char *const argv[]);
    def execv(path, *args)
      FFI.errno = 0
      args.flatten!
      argv = FFI::MemoryPointer.new(:pointer, args.size + 1)
      args.each_with_index do |arg, i|
        argv[i].put_pointer(0, FFI::MemoryPointer.from_string(arg.to_s))
      end
      argv[args.size].put_pointer(0, nil)

      r = Libc.execv(path, argv)
      # if this ever returns, there's been an error
      raise SystemCallError(:execv, FFI.errno)
    end
  end
end
