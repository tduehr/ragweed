module Ragweed; end
module Ragweed::Wraposx::ThreadInfo
  class << self
    #factory method to get a ThreadInfo variant
    def self.get(flavor,tid)
      found = false
      klass = self.constants.detect{|c| con = self.const_get(c); con.kind_of?(Class) && (flavor == con.const_get(:FLAVOR))}
      if klass.nil?
        raise Ragwed::Wraposx::KErrno::INVALID_ARGUMENT
      else
        klass.get(tid)
      end
    end
  end

  # info interfaces
  BASIC_INFO = 3  #basic information

  # following are obsolete interfaces
  # according to the source @ fxr they still work except FIFO
  SCHED_TIMESHARE_INFO = 10
  SCHED_RR_INFO = 11
  # SCHED_FIFO_INFO = 12

  FLAVORS = {
      # define THREAD_BASIC_INFO_COUNT   ((mach_msg_type_number_t)(sizeof(thread_basic_info_data_t) / sizeof(natural_t)))
      BASIC_INFO => {:size => 30, :count => 10},
      # define POLICY_TIMESHARE_INFO_COUNT     ((mach_msg_type_number_t)(sizeof(struct policy_timeshare_info)/sizeof(integer_t)))
      SCHED_TIMESHARE_INFO => {:size => 20, :count => 5},
      # define POLICY_RR_INFO_COUNT    ((mach_msg_type_number_t)(sizeof(struct policy_rr_info)/sizeof(integer_t)))
      SCHED_RR_INFO => {:size => 20,:count => 5},
      # define POLICY_FIFO_INFO_COUNT  ((mach_msg_type_number_t)(sizeof(struct policy_fifo_info)/sizeof(integer_t)))
      # SCHED_FIFO_INFO => {:size => 16,:count => 4} # immediately returns KERNEL_INVALID_POLICY on osx
  }

  module State
    #Thread run states
    RUNNING = 1 #/* thread is running normally */
    STOPPED = 2 #/* thread is stopped */
    WAITING = 3 #/* thread is waiting normally */
    UNINTERRUPTIBLE = 4 #/* thread is in an uninterruptible wait */
    HALTED = 5 #/* thread is halted at a clean point */
  end

  module ThreadInfoMixins
    def initialize(str=nil)
      refresh(str) if (str && !str.empty?)
    end

    # (re)loads the data from str
    def refresh(str)
      fields = self.class.const_get :FIELDS
      pp self.class
      if str and not str.empty?
        str.unpack(fields.map {|x| x[1]}.join("")).each_with_index do |val, i|
          raise "i is nil" if i.nil?
          instance_variable_set "@#{ fields[i][0] }".intern, val
        end            
      end
    end

    def to_s
      fields = self.class.const_get :FIELDS
      fields.map {|f| send(f[0])}.pack(fields.map {|x| x[1]}.join(""))
    end

    def inspect
      body = lambda do
        self.class.const_get(:FIELDS).map do |f|
          "#{f[0]}=#{send(f[0]).to_s}"
        end.join(", ")
      end
      "#<#{self.class.name.split('::').last(2).join('::')} #{body.call}>"
    end

    def self.get(t)
      self.new(Ragweed::Wraposx::thread_info_raw(t, self.class.const_get(:FLAVOR)))
    end

    def get(t)
      refresh(Ragweed::Wraposx::vm_region_raw(t, self.class.const_get(:FLAVOR)))
    end
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
    
    attr_accessor :user_time
    attr_accessor :system_time
    alias_method :__refresh, :refresh
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

    FLAVOR = Ragweed::Wraposx::ThreadInfo::BASIC_INFO
    #(re)loads the data from str
    def refresh(str)
      __refresh str
      @user_time = @user_time_s + (@user_time_us/1000000.0)
      @system_time = @system_time_s + (@system_time_us/1000000.0)
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
    (FIELDS = [ [:max_priority, "I"],
                [:base_priority, "I"],
                [:cur_priority, "I"],
                [:depressed, "I"],
                [:depress_priority, "I"]]).each {|x| attr_accessor x[0]}

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
    (FIELDS = [ [:max_priority, "I"],
                [:base_priority, "I"],
                [:quantum, "I"],
                [:depressed, "I"],
                [:depress_priority, "I"]]).each {|x| attr_accessor x[0]}

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
end

module Ragweed::Wraposx
  class << self

    # Returns the packed string representation of the thread_info_t struct for later parsing.
    # kern_return_t   thread_info
    #                (thread_act_t                     target_thread,
    #                 thread_flavor_t                         flavor,
    #                 thread_info_t                      thread_info,
    #                 mach_msg_type_number_t       thread_info_count);
    def thread_info_raw(thread, flavor)
      info = ("\x00"*1024).to_ptr
      count = ([Ragweed::Wraposx::ThreadInfo::FLAVORS[flavor][:count]].pack("I_")).to_ptr
      r = CALLS["libc!thread_info:IIPP=I"].call(thread,flavor,info,Ragweed::Wraposx::ThreadInfo::FLAVORS[flavor][:count]).first
      raise KernelCallError.new(r) if r != 0
      return info.to_s(Ragweed::Wraposx::ThreadInfo::FLAVORS[flavor][:size])
    end
  end
end
