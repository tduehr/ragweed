module Ragweed; end
module Ragweed::Wrapx
  module EFlags
    CARRY =         0x1
    X0 =            0x2
    PARITY =        0x4
    X1 =            0x8
    ADJUST =        0x10
    X2 =            0x20
    ZERO =          0x40
    SIGN =          0x80
    TRAP =          0x100
    INTERRUPT =     0x200
    DIRECTION =     0x400
    OVERFLOW =      0x800
    IOPL1 =         0x1000
    IOPL2 =         0x2000
    NESTEDTASK =    0x4000
    X3 =            0x8000
    RESUME =        0x10000
    V86MODE =       0x20000
    ALIGNCHECK =    0x40000
    VINT =          0x80000
    VINTPENDING =   0x100000
    CPUID =         0x200000
  end
end

class Ragweed::Wrapx::ThreadContext
  include Ragweed
  (FIELDS = [ [:eax, "I"],
              [:ebx, "I"],
              [:ecx, "I"],
              [:edx, "I"],
              [:edi, "I"],
              [:esi, "I"],
              [:ebp, "I"],
              [:esp, "I"],
              [:ss, "I"],
              [:eflags, "I"],
              [:eip, "I"],
              [:cs, "I"],
              [:ds, "I"],
              [:es, "I"],
              [:fs, "I"],
              [:gs, "I"]]).each {|x| attr_accessor x[0]}
  FIELDTYPES = FIELDS.map {|x| x[1]}.join("")

  def initialize(str=nil)
    refresh(str) if str
  end

  #(re)loads the data fields from str
  def refresh(str)
    if str
      str.unpack(FIELDTYPES).each_with_index do |val, i|
        instance_variable_set "@#{ FIELDS[i][0] }".intern, val
      end            
    end
  end

  def to_s
    FIELDS.map {|f| send(f[0])}.pack(FIELDTYPES)
  end

  def self.get(h)
    Wrapx::thread_suspend(h)
    r = self.new(Wrapx::thread_get_state_raw(h))
    Wrapx::thread_resume(h)
    return r
  end

  def get(h)
    Wrapx::thread_suspend(h)
    r = refresh(Wrapx::thread_get_state_raw(h))
    Wrapx::thread_resume(h)
    return r
  end

  def set(h)
    Wrapx::thread_suspend(h)
    r = Wrapx::thread_set_state_raw(h, self.to_s)
    Wrapx::thread_resume(h)
    return 
  end

  def inspect
    body = lambda do
      FIELDS.map do |f|
        "#{f[0]}=#{send(f[0]).to_s(16)}"
      end.join(", ")
    end
    "#<ThreadContext #{body.call}>"
  end

  def dump(&block)
    maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }      
    maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

    string =<<EOM
    -----------------------------------------------------------------------
    CONTEXT:
    EIP: #{self.eip.to_s(16).rjust(8, "0")} #{maybe_dis.call(self.eip)}

    EAX: #{self.eax.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.eax)}
    EBX: #{self.ebx.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.ebx)}
    ECX: #{self.ecx.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.ecx)}
    EDX: #{self.edx.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.edx)}
    EDI: #{self.edi.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.edi)}
    ESI: #{self.esi.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.esi)}
    EBP: #{self.ebp.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.ebp)}
    ESP: #{self.esp.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.esp)}
    EFL: #{self.eflags.to_s(2).rjust(32, "0")} #{Wrapx::EFlags.flag_dump(self.eflags)}
EOM
  end

  # sets/clears the TRAP flag
  def single_step(v=true)
    if v
      @eflags |= Wrapx::EFlags::TRAP
    else
      @eflags &= ~(Wrapx::EFlags::TRAP)
    end
  end
end

module Ragweed::Wrapx

  # FIXME - constants need to be in separate sub modules
  # XXX - move to class based implementation a la region_info
  # define i386_THREAD_STATE_COUNT   ((mach_msg_type_number_t)( sizeof (i386_thread_state_t) / sizeof (int) ))
  # i386_thread_state_t is a struct w/ 16 uint
  I386_THREAD_STATE_COUNT = 16
  I386_THREAD_STATE = 1
  REGISTER_SYMS = [:eax,:ebx,:ecx,:edx,:edi,:esi,:ebp,:esp,:ss,:eflags,:eip,:cs,:ds,:es,:fs,:gs]

  class << self

    # Returns a Hash of the thread's registers given a thread id.
    #
    # kern_return_t   thread_get_state
    #                (thread_act_t                     target_thread,
    #                 thread_state_flavor_t                   flavor,
    #                 thread_state_t                       old_state,
    #                 mach_msg_type_number_t         old_state_count);
    def thread_get_state(thread)
      state_arr = ("\x00"*SIZEOFINT*I386_THREAD_STATE_COUNT).to_ptr
      count = ([I386_THREAD_STATE_COUNT].pack("I_")).to_ptr
      r = CALLS["libc!thread_get_state:IIPP=I"].call(thread, I386_THREAD_STATE, state_arr, count).first
      raise KernelCallError.new(:thread_get_state, r) if r != 0
      r = state_arr.to_s(I386_THREAD_STATE_COUNT*SIZEOFINT).unpack("I_"*I386_THREAD_STATE_COUNT)
      regs = Hash.new
      I386_THREAD_STATE_COUNT.times do |i|
        regs[REGISTER_SYMS[i]] = r[i]
      end
      return regs
    end

    # Returns string representation of a thread's registers for unpacking given a thread id
    #
    # kern_return_t   thread_get_state
    #                (thread_act_t                     target_thread,
    #                 thread_state_flavor_t                   flavor,
    #                 thread_state_t                       old_state,
    #                 mach_msg_type_number_t         old_state_count);
    def thread_get_state_raw(thread)
      state_arr = ("\x00"*SIZEOFINT*I386_THREAD_STATE_COUNT).to_ptr
      count = ([I386_THREAD_STATE_COUNT].pack("I_")).to_ptr
      r = CALLS["libc!thread_get_state:IIPP=I"].call(thread, I386_THREAD_STATE, state_arr, count).first
      raise KernelCallError.new(:thread_get_state, r) if r != 0
      return state_arr.to_s(I386_THREAD_STATE_COUNT*SIZEOFINT)
    end

    # Sets the register state of thread from a Hash containing it's values.
    #
    # kern_return_t   thread_set_state
    #                (thread_act_t                     target_thread,
    #                 thread_state_flavor_t                   flavor,
    #                 thread_state_t                       new_state,
    #                 target_thread                  new_state_count);
    def thread_set_state(thread, state)
      s = Array.new
      I386_THREAD_STATE_COUNT.times do |i|
        s << state[REGISTER_SYMS[i]]
      end
      s = s.pack("I_"*I386_THREAD_STATE_COUNT).to_ptr
      r = CALLS["libc!thread_set_state:IIPI=I"].call(thread, I386_THREAD_STATE, s, I386_THREAD_STATE_COUNT).first
      raise KernelCallError.new(:thread_set_state, r) if r!= 0
    end

    # Sets the register state of thread from a packed string containing it's values.
    #
    # kern_return_t   thread_set_state
    #                (thread_act_t                     target_thread,
    #                 thread_state_flavor_t                   flavor,
    #                 thread_state_t                       new_state,
    #                 target_thread                  new_state_count);
    def thread_set_state_raw(thread, state)
      r = CALLS["libc!thread_set_state:IIPI=I"].call(thread, I386_THREAD_STATE, state.to_ptr, I386_THREAD_STATE_COUNT).first
      raise KernelCallError.new(:thread_set_state, r) if r!= 0
    end
  end
end
