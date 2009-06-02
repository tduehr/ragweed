require 'dl'

module Ragweed; end
module Ragweed::Wraposx
  
  # These hashes are the magic glue of the ragweed system calls.
  # This one holds the library references from Ruby/DL.
  LIBS = Hash.new do |h, str|
    if not str =~ /^[\.\/].*/
      str = "/usr/lib/" + str
    end
    if not str =~ /.*\.dylib$/
      str = str + ".dylib"
    end
    h[str] = DL.dlopen(str)
  end

  # This hash holds the function references from Ruby/DL.
  # It also auto populates LIBS.
  # CALLS["<library>!<function>:<argument types>=<return type>"]
  # Hash.new is a beautiful thing.
  CALLS = Hash.new do |h, str|
    lib = proc = args = ret = nil
    lib, rest = str.split "!"
    proc, rest = rest.split ":"
    args, ret = rest.split("=") if rest
    ret ||= "0"
    raise "need proc" if not proc
    h[str] = LIBS[lib][proc, ret + args]
  end

  NULL = DL::PtrData.new(0)

  SIZEOFINT = DL.sizeof('I')
  SIZEOFLONG = DL.sizeof('L')

  class << self

    # time_t
    # time(time_t *tloc);
    #
    # see also time(3)
    def time
      CALLS["libc!time:=I"].call.first
    end

    # pid_t
    # getpid(void);
    #
    # see also getpid(2)
    def getpid
      CALLS["libc!getpid:=I"].call.first
    end

    # Apple's ptrace is fairly gimped. The memory read and write functionality has been
    # removed. We will be using mach kernel calls for that. see vm_read and vm_write.
    # for details on ptrace and the process for the Wraposx/debuggerx port see:
    # http://www.matasano.com/log/1100/what-ive-been-doing-on-my-summer-vacation-or-it-has-to-work-otherwise-gdb-wouldnt/
    #
    #int
    #ptrace(int request, pid_t pid, caddr_t addr, int data);
    #
    # see also ptrace(2)
    def ptrace(request, pid, addr, data)
      DL.last_error = 0
      r = CALLS["libc!ptrace:IIII=I"].call(request, pid, addr, data).first
      raise SystemCallError.new("ptrace", DL.last_error) if r == -1 and DL.last_error != 0
      return r
    end

    # Oringially coded for use in debuggerx but I've switched to waitpid for 
    # usability and debugging purposes.
    #
    # Returns status of child when child recieves a signal.
    #
    # pid_t
    # wait(int *stat_loc);
    #
    # see also wait(2)
    def wait
      status = ("\x00"*SIZEOFINT).to_ptr
      r = CALLS["libc!wait:=I"].call(status).first
      raise SystemCallError.new("wait", DL.last_error) if r== -1
      return status.to_s(SIZEOFINT).unpack('i_').first
    end

    # The wait used in debuggerx.
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
    def waitpid(pid, opt=1)
      pstatus = ("\x00"*SIZEOFINT).to_ptr
      r = CALLS["libc!waitpid:IPI=I"].call(pid, pstatus, opt).first
      raise SystemCallError.new("waitpid", DL.last_error) if r== -1
      
      # maybe I should return a Hash?
      return [r, pstatus.to_s(SIZEOFINT).unpack('i_').first]
    end

    # From docs at http://web.mit.edu/darwin/src/modules/xnu/osfmk/man/mach_task_self.html
    # Returns send rights to the task's kernel port.
    #
    # mach_port_t
    # mach_task_self(void)
    #
    # There is no man page for this call.
    def mach_task_self
      CALLS["libc!mach_task_self:=I"].call().first
    end

    # Require sudo to use as of 10.5 or 10.4.11(ish)
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
      port = ("\x00"*SIZEOFINT).to_ptr
      r = CALLS["libc!task_for_pid:IIP=I"].call(target, pid, port).first
      raise KernelCallError.new(:task_for_pid, r) if r != 0
      return port.to_s(SIZEOFINT).unpack('i_').first
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
      threads = ("\x00"*SIZEOFINT).to_ptr
      #threads = 0
      count = ("\x00"*SIZEOFINT).to_ptr
      r = CALLS["libc!task_threads:IPP=I"].call(port, threads, count).first
      t = DL::PtrData.new(threads.to_s(SIZEOFINT).unpack('i_').first)
      raise KernelCallError.new(:task_threads, r) if r != 0
      return t.to_a("I", count.to_s(SIZEOFINT).unpack('I_').first)
    end

    # Sends a signal to a process
    #
    # int
    # kill(pid_t pid, int sig);
    #
    # See kill(2)
    def kill(pid, sig)
      DL.last_error = 0
      r = CALLS["libc!kill:II=I"].call(pid,sig).first
      raise SystemCallError.new("kill",DL.last_error) if r != 0            
    end

    # function to marshal 32bit integers into DL::PtrData objects
    # necessary due to Ruby/DL not properly dealing with 31 and 32 bit integers
    def dl_bignum_to_ulong(x)
      if x.class == Fixnum
        return DL::PtrData.new(x)
      else
        # shut up
        c = x / 4
        e = x - (c * 4)
        v = DL::PtrData.new 0
        v += c
        v += c
        v += c
        v += c
        v += e
        return v
      end
    end

    # Reads sz bytes from task's address space starting at addr.
    #
    # kern_return_t   vm_read
    #                (vm_task_t                          target_task,
    #                 vm_address_t                           address,
    #                 vm_size_t                                 size,
    #                 size                                  data_out,
    #                 target_task                         data_count);
    #
    # There is no man page for this function.
    def vm_read(task, addr, sz=256)
      addr = dl_bignum_to_ulong(addr)
      buf = ("\x00" * sz).to_ptr
      len = (sz.to_l32).to_ptr
      r = CALLS["libc!vm_read_overwrite:IPIPP=I"].call(task, addr, sz, buf, len).first
      raise KernelCallError.new(:vm_read, r) if r != 0
      return buf.to_str(len.to_str(4).to_l32)
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
      addr = dl_bignum_to_ulong(addr)
      val = val.to_ptr
      r = CALLS["libc!vm_write:IPPI=I"].call(task, addr, val, val.size).first
      raise KernelCallError.new(:vm_write, r) if r != 0
      return nil
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
      addr = dl_bignum_to_ulong(addr)
      setmax = setmax ? 1 : 0
      r = CALLS["libc!vm_protect:IPIII=I"].call(task,addr,size,setmax,prot).first
      raise KernelCallError.new(:vm_protect, r) if r != 0
      return nil
    end

    # Resumes a suspended thread by id.
    #
    # kern_return_t   thread_resume
    #                (thread_act_t                     target_thread);
    #
    # There is no man page for this function.
    def thread_resume(thread)
      r = CALLS["libc!thread_resume:I=I"].call(thread).first
      raise KernelCallError.new(:thread_resume, r) if r != 0
    end

    # Suspends a thread by id.
    #
    # kern_return_t   thread_suspend
    #                (thread_act_t                     target_thread);
    #
    # There is no man page for this function.
    def thread_suspend(thread)
      r = CALLS["libc!thread_suspend:I=I"].call(thread).first
      raise KernelCallError.new(:thread_suspend, r) if r != 0
    end

    # Suspends a task by id.
    #
    # kern_return_t   task_suspend
    #                (task_t          task);
    #
    # There is no man page for this function.
    def task_suspend(task)
      r = CALLS["libc!task_suspend:I=I"].call(task).first
      raise KernelCallError.new(:task_suspend, r) if r != 0
    end

    # Resumes a suspended task by id.
    #
    # kern_return_t   task_resume
    #                (task_t         task);
    #
    # There is no man page for this function.
    def task_resume(task)
      r = CALLS["libc!task_resume:I=I"].call(task).first
      raise KernelCallError.new(:task_resume, r) if r != 0            
    end

    # Used to query kernel state.
    # Returns output buffer on successful call or required buffer size on ENOMEM.
    #
    # mib: and array of integers decribing the MIB
    # newb: the buffer to replace the old information (only used on some commands so it defaults to empty)
    # oldlenp: output buffer size
    #
    # int
    #     sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
    #
    # this function doesn't really match the Ruby Way(tm)
    #
    # see sysctl(8)
    def sysctl(mib,oldlen=0,newb="")
      DL.last_error = 0
      mibp = mib.pack("I_"*mib.size).to_ptr
      oldlenp = [oldlen].pack("I_").to_ptr
      namelen = mib.size
      oldp = (oldlen > 0 ? "\x00"*oldlen : NULL)
      newp = (newb.empty? ? NULL : newb.to_ptr)
      newlen = newb.size
      r = CALLS["libc!sysctl:PIPPPI=I"].call(mibp, namelen, oldp, oldlenp, newp, newlen).first
      return oldlenp.to_str(SIZEOFINT).unpack("I_").first if (r == -1 and DL.last_error == Errno::ENOMEM::Errno)
      raise SystemCallError.new("sysctl", DL.last_error) if r != 0
      return oldp.to_str(oldlenp.to_str(SIZEOFINT).unpack("I_").first)
    end

    # Used to query kernel state.
    # Returns output buffer on successful call and required buffer size as an Array.
    #
    # mib: and array of integers decribing the MIB
    # newb: the buffer to replace the old information (only used on some commands so it defaults to empty)
    # oldlenp: output buffer size
    #
    # int
    #     sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen);
    #
    # this function doesn't really match the Ruby Way(tm)
    #
    # see sysctl(8)
    def sysctl_raw(mib,oldlen=0,newb="")
      DL.last_error = 0
      mibp = mib.pack('I_'*mib.size).to_ptr
      oldlenp = [oldlen].pack("I_").to_ptr
      namelen = mib.size
      oldp = (oldlen > 0 ? ("\x00"*oldlen).to_ptr : NULL)
      newp = (newb.empty? ? NULL : newb.to_ptr)
      newlen = newb.size
      r = CALLS["libc!sysctl:PIPPPI=I"].call(mibp, namelen, oldp, oldlenp, newp, newlen).first
      ret = (DL.last_error == Errno::ENOMEM::Errno ? NULL : oldp)
      raise SystemCallError.new("sysctl", DL.last_error) if (r != 0 and DL.last_error != Errno::ENOMEM::Errno)
      return [ret,oldlenp.to_str(SIZEOFINT).unpack("I_").first]
    end

    # Changes execution to file in path with *args as though called from command line.
    #
    # int
    # execv(const char *path, char *const argv[]);
    def execv(path,*args)
      DL.last_error = 0
      argv = ""
      args.flatten.each { |arg| argv = "#{ argv }#{arg.to_ptr.ref.to_s(SIZEOFINT)}" }
      argv += ("\x00"*SIZEOFINT)
      r = CALLS["libc!execv:SP"].call(path,argv.to_ptr).first
      raise SystemCallError.new("execv", DL.last_error) if r == -1
      return r
    end
  end
end

# if __FILE__ == $0
#     include Ragweed
#     require 'pp'
#     require 'constants'
#     addr = data = 0
#     pid = 1319
#     int = "\x00" * 4
#     port = 0
#     Wraposx::ptrace(Wraposx::Ptrace::ATTACH,pid,0,0)
#     #  status = Wraposx::waitpid(pid,0)
#     #  Wraposx::ptrace(Wraposx::Ptrace::CONTINUE,pid,1,0)
#     mts = Wraposx::mach_task_self
#     port = Wraposx::task_for_pid(mts,pid)
#     port2 = Wraposx::task_for_pid(mts,pid)
#     threads = Wraposx::task_threads(port)
#     state = Wraposx::thread_get_state(threads.first)
#     pp port
#     pp port2
#     pp threads
#     pp state
#     #  Wraposx::thread_set_state(threads.first,state)
#     Wraposx::ptrace(Wraposx::Ptrace::DETACH,pid,0,0)
# end
