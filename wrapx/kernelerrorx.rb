# Exception objects for kernel errors likely in wrapx
# If this were a C extension I'd use #ifdef on each to only create the required ones.

module Ragweed; end
module Ragweed::Wrapx; end
module Ragweed::Wrapx::KernelReturn
  SUCCESS =               { :value => 0, :message => 'Not an error'}
  INVALID_ADDRESS =       { :value => 1, :message => 'Specified address is not currently valid.'}
  PROTECTION_FAILURE =    { :value => 2, :message => 'Specified memory is valid, but does not permit the required forms of access.'}
  NO_SPACE =              { :value => 3, :message => 'The address range specified is already in use, or no address range of the size specified could be found.'}
  INVALID_ARGUMENT =      { :value => 4, :message => 'The function requested was not applicable to this type of argument, or an argument is invalid'}
  FAILURE =               { :value => 5, :message => 'The function could not be performed.  A catch-all.'}
  RESOURCE_SHORTAGE =     { :value => 6, :message => 'A system resource could not be allocated to fulfill this request.  This failure may not be permanent.'}
  NOT_RECEIVER =          { :value => 7, :message => 'The task in question does not hold receive rights for the port argument.'}
  NO_ACCESS =             { :value => 8, :message => 'Bogus access restriction.'}
  MEMORY_FAILURE =        { :value => 9, :message => 'During a page fault, the target address refers to a memory object that has been destroyed.  This failure is permanent.'}
  MEMORY_ERROR =          { :value => 10, :message => 'During a page fault, the memory object indicated that the data could not be returned.  This failure may be temporary; future attempts to access this same data may succeed, as defined by the memory object.'}
  ALREADY_IN_SET =        { :value => 11, :message => 'The receive right is already a member of the portset.'}
  NOT_IN_SET =            { :value => 12, :message => 'The receive right is not a member of a port set.'}
  NAME_EXISTS =           { :value => 13, :message => 'The name already denotes a right in the task.'}
  ABORTED =               { :value => 14, :message => 'The operation was aborted.  Ipc code will catch this and reflect it as a message error.'}
  INVALID_NAME =          { :value => 15, :message => 'The name doesn\'t denote a right in the task.'}
  INVALID_TASK =          { :value => 16, :message => 'Target task isn\'t an active task.'}
  INVALID_RIGHT =         { :value => 17, :message => 'The name denotes a right, but not an appropriate right.'}
  INVALID_VALUE =         { :value => 18, :message => 'A blatant range error.'}
  UREFS_OVERFLOW =        { :value => 19, :message => 'Operation would overflow limit on user-references.'}
  INVALID_CAPABILITY =    { :value => 20, :message => 'The supplied (port) capability is improper.'}
  RIGHT_EXISTS =          { :value => 21, :message => 'The task already has send or receive rights for the port under another name.'}
  INVALID_HOST =          { :value => 22, :message => 'Target host isn\'t actually a host.'}
  MEMORY_PRESENT =        { :value => 23, :message => 'An attempt was made to supply "precious" data for memory that is already present in a memory object.'}
  MEMORY_DATA_MOVED =     { :value => 24, :message => 'A page was requested of a memory manager via memory_object_data_request for an object using a MEMORY_OBJECT_COPY_CALL strategy, with the VM_PROT_WANTS_COPY flag being used to specify that the page desired is for a copy of the object, and the memory manager has detected the page was pushed into a copy of the object while the kernel was walking the shadow chain from the copy to the object. This error code is delivered via memory_object_data_error and is handled by the kernel (it forces the kernel to restart the fault). It will not be seen by users.'}
  MEMORY_RESTART_COPY =   { :value => 25, :message => 'A strategic copy was attempted of an object upon which a quicker copy is now possible. The caller should retry the copy using vm_object_copy_quickly. This error code is seen only by the kernel.'}
  INVALID_PROCESSOR_SET = { :value => 26, :message => 'An argument applied to assert processor set privilege was not a processor set control port.'}
  POLICY_LIMIT =          { :value => 27, :message => 'The specified scheduling attributes exceed the thread\'s limits.'}
  INVALID_POLICY =        { :value => 28, :message => 'The specified scheduling policy is not currently enabled for the processor set.'}
  INVALID_OBJECT =        { :value => 29, :message => 'The external memory manager failed to initialize the memory object.'}
  ALREADY_WAITING =       { :value => 30, :message => 'A thread is attempting to wait for an event for which  there is already a waiting thread.'}
  DEFAULT_SET =           { :value => 31, :message => 'An attempt was made to destroy the default processor set.'}
  EXCEPTION_PROTECTED =   { :value => 32, :message => 'An attempt was made to fetch an exception port that is protected, or to abort a thread while processing a protected exception.'}
  INVALID_LEDGER =        { :value => 33, :message => 'A ledger was required but not supplied.'}
  INVALID_MEMORY_CONTROL= { :value => 34, :message => 'The port was not a memory cache control port.'}
  INVALID_SECURITY =      { :value => 35, :message => 'An argument supplied to assert security privilege was not a host security port.'}
  NOT_DEPRESSED =         { :value => 36, :message => 'thread_depress_abort was called on a thread which was not currently depressed.'}
  TERMINATED =            { :value => 37, :message => 'Object has been terminated and is no longer available'}
  LOCK_SET_DESTROYED =    { :value => 38, :message => 'Lock set has been destroyed and is no longer available.'}
  LOCK_UNSTABLE =         { :value => 39, :message => 'The thread holding the lock terminated before releasing the lock'}
  LOCK_OWNED =            { :value => 40, :message => 'The lock is already owned by another thread'}
  LOCK_OWNED_SELF =       { :value => 41, :message => 'The lock is already owned by the calling thread'}
  SEMAPHORE_DESTROYED =   { :value => 42, :message => 'Semaphore has been destroyed and is no longer available.'}
  RPC_SERVER_TERMINATED = { :value => 43, :message => 'Return from RPC indicating the target server was terminated before it successfully replied '}
  RPC_TERMINATE_ORPHAN =  { :value => 44, :message => 'Terminate an orphaned activation.'}
  RPC_CONTINUE_ORPHAN =   { :value => 45, :message => 'Allow an orphaned activation to continue executing.'}
  NOT_SUPPORTED =         { :value => 46, :message => 'Empty thread activation (No thread linked to it)'}
  NODE_DOWN =             { :value => 47, :message => 'Remote node down or inaccessible.'}
  NOT_WAITING =           { :value => 48, :message => 'A signalled thread was not actually waiting.'}
  OPERATION_TIMED_OUT =   { :value => 49, :message => 'Some thread-oriented operation (semaphore_wait) timed out'}
  RETURN_MAX =            { :value => 0x100, :message => 'Maximum return value allowable'}
  
  module_function
  # Much like Signals.list returns a hash of the possible kernel call return values.
  def list
    constants.inject({}){|a, c| a.merge! c => const_get(c)}
  end
end

module Ragweed::Wrapx::KErrno; end

# Exception class for mach kernel calls. Works mostly like SystemCallError.
# Subclasses are individual error conditions and case equality (===) is done by class then error number (KErrno)
class Ragweed::Wrapx::KernelCallError < StandardError
  DEFAULT_MESSAGE = "Unknown Error"
  attr_reader :kerrno
  
  # Returns a subclass of KernelCallError based on the KernelReturn value err
  def self.new(msg = "", err = nil)
    if msg.kind_of? Fixnum
      err = msg
      msg = ""
    end
    mesg = ""

    klass = Ragweed::Wrapx::KErrno.constants.detect{|x| Ragweed::Wrapx::KErrno.const_get(x).const_get("KErrno") == err}
    if (klass.nil? or klass.empty?)
      o = self.allocate
      o.instance_variable_set("@kerrno", err)
      mesg = "Unknown kernel error"
    else
      o = Ragweed::Wrapx::KErrno.const_get(klass).allocate
      mesg = Ragweed::Wrapx::KernelReturn.const_get(klass)[:message]
    end
    
    if o.class.const_defined?("KErrno")
      o.instance_variable_set("@kerrno", o.class.const_get("KErrno"))
    else
      o.instance_variable_set("@kerrno", err)
      mesg = "#{mesg}: #{err}" if err
    end

    mesg = "#{mesg} - #{msg}" if !(msg.nil? or msg.empty?)  
    o.send(:initialize, mesg)
    return o
  end

  # Case equality. Returns true if self and other are KernelCallError or when error numbers match.
  def self.===(other)
    return false if not other.kind_of?(Ragweed::Wrapx::KernelCallError)
    return true if self == Ragweed::Wrapx::KernelCallError
    
    begin
      return self.const_get("KErrno") == other.const_get("KErrno")
    rescue
      return false
    end
  end

  def initialize(msg)
    super msg
  end

  # This block builds the subclasses for KernelCallError
  Ragweed::Wrapx::KernelReturn.list.each do |k, v|
    case k.intern
    when :SUCCESS
    when :RETURN_MAX
    else
      klass = Ragweed::Wrapx::KErrno.const_set(k, Class.new(Ragweed::Wrapx::KernelCallError){
        def self.new(msg = "")
          o = self.allocate
          o.instance_variable_set "@kerrno", self.const_get("KErrno")
          mesg = ""
          klass = self.name.split("::").last
          if Ragweed::Wrapx::KernelReturn.const_defined?(klass)
            mesg = Ragweed::Wrapx::KernelReturn.const_get(klass)[:message]
          else
            mesg = "Unknown kernel error"
          end
          mesg = "#{mesg} - #{msg}" if not (msg.nil? or msg.empty?)
          o.send(:initialize, mesg)
          puts self
          return o
        end
      })
      klass.const_set "KErrno", v[:value]
      klass.const_set "DEFAULT_MESSAGE", v[:message]
    end
  end
end
