module Ragweed; end
module Ragweed::Wraposx::ThreadInfo
  # info interfaces
  BASIC_INFO = 3  #basic information

  # following are obsolete interfaces
  # according to the source @ fxr they still work except FIFO
  SCHED_TIMESHARE_INFO = 10
  SCHED_RR_INFO = 11
  # SCHED_FIFO_INFO = 12

  module State
    #Thread run states
    RUNNING = 1 #/* thread is running normally */
    STOPPED = 2 #/* thread is stopped */
    WAITING = 3 #/* thread is waiting normally */
    UNINTERRUPTIBLE = 4 #/* thread is in an uninterruptible wait */
    HALTED = 5 #/* thread is halted at a clean point */
  end

  # struct thread_basic_info
  # {
  #        time_value_t     user_time;
  #        time_value_t   system_time;
  #        integer_t        cpu_usage;
  #        policy_t            policy;
  #        integer_t        run_state;
  #        integer_t            flags;
  #        integer_t    suspend_count;
  #        integer_t       sleep_time;
  # };
  class Basic
    include Ragweed::Wraposx::ThreadInfo::ThreadInfoMixins
    module Flags
      #Thread flags (flags field).
      SWAPPED = 0x1 #/* thread is swapped out */
      IDLE = 0x2 #/* thread is an idle thread */
    end

    FLAVOR = Ragweed::Wraposx::ThreadInfo::BASIC_INFO
    layout :user_time, Ragweed::Wraposx::TimeValue,
           :system_time, Ragweed::Wraposx::TimeValue,
           :cpu_usage, :int,
           :policy, :policy_t,
           :run_state, :int,
           :flags, :int,
           :suspend_count, :int,
           :sleep_time, :int

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
      flags:         #{self.flags.to_s(2).rjust(32, "0")} #{Flags.flag_dump(self.flags)}
EOM
    end
  end

  # struct policy_timeshare_info
  # {
  #        int            max_priority;
  #        int           base_priority;
  #        int            cur_priority;
  #        boolean_t         depressed;
  #        int        depress_priority;
  # };
  class SchedTimeshare
    include Ragweed::Wraposx::ThreadInfo::ThreadInfoMixins
    layout :max_priority, :int,
           :base_priority, :int,
           :cur_priority, :int,
           :depress_priority, :int

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      Timeshare Info:
      max_priority:     #{self.max_priority.to_s.rjust(8, "0")} #{maybe_hex.call(self.max_priority)}
      base_priority:    #{self.base_priority.to_s.rjust(8, "0")} #{maybe_hex.call(self.base_priority)}
      cur_priority:     #{self.cpu_usage.to_s.rjust(8, "0")} #{maybe_hex.call(self.cur_priority)}
      depressed:        #{(!self.depressed.zero?).to_s.rjust(8, " ")} #{maybe_hex.call(self.depressed)}
      depress_priority: #{self.depress_priority.to_s.rjust(8, "0")} #{maybe_hex.call(self.depressed_priority)}
EOM
    end
  end

  # struct policy_rr_info
  # {
  #        int          max_priority;
  #        int         base_priority;
  #        int               quantum;
  #        boolean_t       depressed;
  #        int      depress_priority;
  # };
  class SchedRr
    include Ragweed::Wraposx::ThreadInfo::ThreadInfoMixins
    layout :max_priority, :int,
           :base_priority, :int,
           :quantum, :int,
           :depressed, :boolean_t,
           :depress_priority, :int

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      Round Robin Info:
      max_priority:     #{self.max_priority.to_s.rjust(8, "0")} #{maybe_hex.call(self.max_priority)}
      base_priority:    #{self.base_priority.to_s.rjust(8, "0")} #{maybe_hex.call(self.base_priority)}
      quantum:          #{self.quantum.to_s.rjust(8, "0")} #{maybe_hex.call(self.quantum)}
      depressed:        #{(!self.depressed.zero?).to_s.rjust(8, " ")} #{maybe_hex.call(self.depressed)}
      depress_priority: #{self.depress_priority.to_s.rjust(8, "0")} #{maybe_hex.call(self.depressed_priority)}
EOM
    end
  end

  FLAVORS = {
      # define THREAD_BASIC_INFO_COUNT   ((mach_msg_type_number_t)(sizeof(thread_basic_info_data_t) / sizeof(natural_t)))
      BASIC_INFO => {:size => 30, :count => 10, :class => Basic},
      # define POLICY_TIMESHARE_INFO_COUNT     ((mach_msg_type_number_t)(sizeof(struct policy_timeshare_info)/sizeof(integer_t)))
      SCHED_TIMESHARE_INFO => {:size => 20, :count => 5, :class => SchedTimeshare},
      # define POLICY_RR_INFO_COUNT    ((mach_msg_type_number_t)(sizeof(struct policy_rr_info)/sizeof(integer_t)))
      SCHED_RR_INFO => {:size => 20,:count => 5, :class => SchedRr},
      # define POLICY_FIFO_INFO_COUNT  ((mach_msg_type_number_t)(sizeof(struct policy_fifo_info)/sizeof(integer_t)))
      # SCHED_FIFO_INFO => {:size => 16,:count => 4} # immediately returns KERNEL_INVALID_POLICY on osx
  }
end

module Ragweed::Wraposx
  class << self

    # Returns the packed string representation of the thread_info_t struct for later parsing.
    #
    # kern_return_t   thread_info
    #                (thread_act_t                     target_thread,
    #                 thread_flavor_t                         flavor,
    #                 thread_info_t                      thread_info,
    #                 mach_msg_type_number_t       thread_info_count);
    def thread_info(thread, flavor)
      info = FFI::MemoryPointer.new(ThreadInfo::FLAVORS[flavor][:class], 1)
      count = FFI::MemoryPointer.new(:int, 1).write_int(ThreadInfo::FLAVORS[flavor][:count])
      r = Libc.thread_info(thread, flavor, info, count)
      raise KernelCallError.new(r) if r != 0
      ThreadInfo::FLAVORS[flavor][:class].new info
    end
  end
end
