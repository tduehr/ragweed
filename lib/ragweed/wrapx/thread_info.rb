module Ragweed; end
module Ragweed::Wrapx::ThreadState
  #Thread run states
  RUNNING = 1 #/* thread is running normally */
  STOPPED = 2 #/* thread is stopped */
  WAITING = 3 #/* thread is waiting normally */
  UNINTERRUPTIBLE = 4 #/* thread is in an uninterruptible wait */
  HALTED = 5 #/* thread is halted at a clean point */
end

module Ragweed::Wrapx::TFlags
  #Thread flags (flags field).
  SWAPPED = 0x1 #/* thread is swapped out */
  IDLE = 0x2 #/* thread is an idle thread */
end
    
class Ragweed::Wrapx::ThreadInfo
  include Ragweed
  attr_accessor :user_time
  attr_accessor :system_time
  (FIELDS = [ [:user_time_s, "I"],
              [:user_time_us, "I"],
              [:system_time_s, "I"],
              [:system_time_us, "I"],
              [:cpu_usage, "I"],
              [:policy, "I"],
              [:run_state, "I"],
              [:flags, "I"],
              [:suspend_count, "I"],
              [:sleep_time, "I"]]).each {|x| attr_accessor x[0]}

  def initialize(str=nil)
    refresh(str) if str
  end

  #(re)loads the data from str
  def refresh(str)
    if str and not str.empty?
      str.unpack(FIELDS.map {|x| x[1]}.join("")).each_with_index do |val, i|
        raise "i is nil" if i.nil?
        instance_variable_set "@#{ FIELDS[i][0] }".intern, val
      end
    end
    @user_time = @user_time_s + (@user_time_us/1000000.0)
    @system_time = @system_time_s + (@system_time_us/1000000.0)
  end

  def to_s
    FIELDS.map {|f| send(f[0])}.pack(FIELDS.map {|x| x[1]}.join(""))
  end

  def self.get(t)
    self.new(Wrapx::thread_info_raw(t))
  end

  def get(t)
    refresh(Wrapx::thread_info_raw(t))
  end

  def inspect
    body = lambda do
      FIELDS.map do |f|
        "#{f[0]}=#{send(f[0]).to_s}"
      end.join(", ")
    end
    "#<ThreadInfo #{body.call}>"
  end

  def dump(&block)
    maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
    maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

    string =<<EOM
    -----------------------------------------------------------------------
    INFO:
    user_time:     #{self.user_time.to_s.rjust(8, "0")} #{maybe_hex.call(self.user_time)}
    system_time:   #{self.system_time.to_s.rjust(8, "0")} #{maybe_hex.call(self.system_time)}
    cpu_usage:     #{self.cpu_usage.to_s.rjust(8, "0")} #{maybe_hex.call(self.cpu_usage)}
    policy:        #{self.policy.to_s.rjust(8, "0")} #{maybe_hex.call(self.policy)}
    run_state:     #{self.run_state.to_s.rjust(8, "0")} #{maybe_hex.call(self.run_state)}
    suspend_count: #{self.suspend_count.to_s.rjust(8, "0")} #{maybe_hex.call(self.suspend_count)}
    sleep_time:    #{self.sleep_time.to_s.rjust(8, "0")} #{maybe_hex.call(self.sleep_time)}
    flags:         #{self.flags.to_s(2).rjust(32, "0")} #{Wrapx::TFlags.flag_dump(self.flags)}
EOM
  end
end

module Ragweed::Wrapx

  # FIXME - constants should be un separate sub-modules
  # XXX - implement more thread info flavors (if possible)
  # XXX - move to class based implementation a la region_info
  # info interfaces
  THREAD_BASIC_INFO = 3  #basic information

  # following are obsolete interfaces
  THREAD_SCHED_TIMESHARE_INFO = 10
  THREAD_SCHED_RR_INFO = 11
  THREAD_SCHED_FIFO_INFO = 12

  # define THREAD_BASIC_INFO_COUNT   ((mach_msg_type_number_t)(sizeof(thread_basic_info_data_t) / sizeof(natural_t)))
  # the two time fields are each two ints
  THREAD_BASIC_INFO_COUNT = 10

  class << self

    # Returns the packed string representation of the thread_info_t struct for later parsing.
    # kern_return_t   thread_info
    #                (thread_act_t                     target_thread,
    #                 thread_flavor_t                         flavor,
    #                 thread_info_t                      thread_info,
    #                 mach_msg_type_number_t       thread_info_count);
    def thread_info_raw(thread)
      info = ("\x00"*1024).to_ptr
      count = ([THREAD_BASIC_INFO_COUNT].pack("I_")).to_ptr
      r = CALLS["libc!thread_info:IIPP=I"].call(thread,THREAD_BASIC_INFO,info,count).first
      raise KernelCallError.new(:thread_info, r) if r != 0
      return info.to_s(SIZEOFINT*THREAD_BASIC_INFO_COUNT)
    end
  end
end
