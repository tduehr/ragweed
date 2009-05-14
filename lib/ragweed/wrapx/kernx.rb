# Exception objects for kernel errors likely in wrapx
# FIXME - needs class for each error which is a subclass of KernelError

module Ragweed; end
module Ragweed::Wrapx; end
module Ragweed::Wrapx::KernelError
  SUCCESS =               0
  INVALID_ADDRESS =       1 #Specified address is not currently valid.
  PROTECTION_FAILURE =    2 #Specified memory is valid, but does not permit the required forms of access.
  NO_SPACE =              3 #The address range specified is already in use, or no address range of the size specified could be found.
  INVALID_ARGUMENT =      4 #The function requested was not applicable to this type of argument, or an argument is invalid
  FAILURE =               5 #The function could not be performed.  A catch-all.
  RESOURCE_SHORTAGE =     6 #A system resource could not be allocated to fulfill this request.  This failure may not be permanent.
  NOT_RECEIVER =          7 #The task in question does not hold receive rights for the port argument.
  NO_ACCESS =             8 #Bogus access restriction.
  MEMORY_FAILURE =        9 #During a page fault, the target address refers to a memory object that has been destroyed.  This failure is permanent.
  MEMORY_ERROR =          10 #During a page fault, the memory object indicated that the data could not be returned.  This failure may be temporary; future attempts to access this same data may succeed, as defined by the memory object.
  ALREADY_IN_SET =        11 #The receive right is already a member of the portset.
  NOT_IN_SET =            12 #The receive right is not a member of a port set.
  NAME_EXISTS =           13 #The name already denotes a right in the task.
  ABORTED =               14 #The operation was aborted.  Ipc code will catch this and reflect it as a message error.
  INVALID_NAME =          15 #The name doesn't denote a right in the task.
  INVALID_TASK =          16 #Target task isn't an active task.
  INVALID_RIGHT =         17 #The name denotes a right, but not an appropriate right.
  INVALID_VALUE =         18 #A blatant range error.
  UREFS_OVERFLOW =        19 #Operation would overflow limit on user-references.
  INVALID_CAPABILITY =    20 #The supplied (port) capability is improper.
  RIGHT_EXISTS =          21 #The task already has send or receive rights for the port under another name.
  INVALID_HOST =          22 #Target host isn't actually a host.
  MEMORY_PRESENT =        23 #An attempt was made to supply "precious" data for memory that is already present in a memory object.
  MEMORY_DATA_MOVED =     24 #A page was requested of a memory manager via memory_object_data_request for an object using a MEMORY_OBJECT_COPY_CALL strategy, with the VM_PROT_WANTS_COPY flag being used to specify that the page desired is for a copy of the object, and the memory manager has detected the page was pushed into a copy of the object while the kernel was walking the shadow chain from the copy to the object. This error code is delivered via memory_object_data_error and is handled by the kernel (it forces the kernel to restart the fault). It will not be seen by users.
  MEMORY_RESTART_COPY =   25 #A strategic copy was attempted of an object upon which a quicker copy is now possible. The caller should retry the copy using vm_object_copy_quickly. This error code is seen only by the kernel.
  INVALID_PROCESSOR_SET = 26 #An argument applied to assert processor set privilege was not a processor set control port.
  POLICY_LIMIT =          27 #The specified scheduling attributes exceed the thread's limits.
  INVALID_POLICY =        28 #The specified scheduling policy is not currently enabled for the processor set.
  INVALID_OBJECT =        29 #The external memory manager failed to initialize the memory object.
  ALREADY_WAITING =       30 #A thread is attempting to wait for an event for which  there is already a waiting thread.
  DEFAULT_SET =           31 #An attempt was made to destroy the default processor set.
  EXCEPTION_PROTECTED =   32 #An attempt was made to fetch an exception port that is protected, or to abort a thread while processing a protected exception.
  INVALID_LEDGER =        33 #A ledger was required but not supplied.
  INVALID_MEMORY_CONTROL= 34 #The port was not a memory cache control port.
  INVALID_SECURITY =      35 #An argument supplied to assert security privilege     was not a host security port.
  NOT_DEPRESSED =         36 #thread_depress_abort was called on a thread which was not currently depressed.
  TERMINATED =            37 #Object has been terminated and is no longer available
  LOCK_SET_DESTROYED =    38 #Lock set has been destroyed and is no longer available.
  LOCK_UNSTABLE =         39 #The thread holding the lock terminated before releasing the lock
  LOCK_OWNED =            40 #The lock is already owned by another thread
  LOCK_OWNED_SELF =       41 #The lock is already owned by the calling thread
  SEMAPHORE_DESTROYED =   42 #Semaphore has been destroyed and is no longer available.
  RPC_SERVER_TERMINATED = 43 #Return from RPC indicating the target server was terminated before it successfully replied 
  RPC_TERMINATE_ORPHAN =  44 #Terminate an orphaned activation.
  RPC_CONTINUE_ORPHAN =   45 #Allow an orphaned activation to continue executing.
  NOT_SUPPORTED =         46 #Empty thread activation (No thread linked to it)
  NODE_DOWN =             47 #Remote node down or inaccessible.
  NOT_WAITING =           48 #A signalled thread was not actually waiting. */
  OPERATION_TIMED_OUT =   49 #Some thread-oriented operation (semaphore_wait) timed out
  RETURN_MAX =            0x100 #Maximum return value allowable
end

module Ragweed::Wrapx
  class KernelCallError < StandardError
    attr_reader :error
    attr_reader :call
    attr_reader :msg
    def initialize(sym=nil, err = nil)
      if sym.kind_of?(Numeric)
        sym, err = err, sym
      end

      @call = sym

      case err
      when nil
        m = "Unspecified Kernel Error"
      when Ragweed::Wrapx::KernelError::INVALID_ADDRESS
        m = "Invalid Address"
      when Ragweed::Wrapx::KernelError::PROTECTION_FAILURE
        m = "Protection Failure"
      when Ragweed::Wrapx::KernelError::FAILURE
        m = "Failure"
      when Ragweed::Wrapx::KernelError::INVALID_ARGUMENT
        m = "Invalid Argument"
      else
        m = "Unknown Error"
      end
      @error = err ? err : -1
      @msg = "#{(@call ? @call.to_s + ": " : "")}(#{@error}) #{ m }"
      super(@msg)
    end
  end
end