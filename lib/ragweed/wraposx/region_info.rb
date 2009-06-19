module Ragweed; end
module Ragweed::Wraposx; end
module Ragweed::Wraposx::Vm
  # these are flavor arguments for vm_region
  # more to be added as support for 64bit processes gets added
  REGION_BASIC_INFO = 10
  REGION_EXTENDED_INFO = 11
  REGION_TOP_INFO = 12

  # behavior identifiers
  BEHAVIOR_DEFAULT = 0    # /* default */
  BEHAVIOR_RANDOM = 1     # /* random */
  BEHAVIOR_SEQUENTIAL = 2 # /* forward sequential */
  BEHAVIOR_RSEQNTL = 3    # /* reverse sequential */
  BEHAVIOR_WILLNEED = 4   # /* will need in near future */
  BEHAVIOR_DONTNEED = 5   # /* dont need in near future */

  #Virtual memory map inheritance values for vm_inherit_t
  INHERIT_SHARE = 0       # /* share with child */
  INHERIT_COPY = 1        # /* copy into child */
  INHERIT_NONE = 2        # /* absent from child */
  INHERIT_DONATE_COPY = 3 # /* copy and delete */
  INHERIT_DEFAULT = 1     # VM_INHERIT_COPY
  INHERIT_LAST_VALID = 2  # VM_INHERIT_NONE

  #define VM_REGION_BASIC_INFO_COUNT ((mach_msg_type_number_t) (sizeof(vm_region_basic_info_data_t)/sizeof(int)))
  #define VM_REGION_EXTENDED_INFO_COUNT   ((mach_msg_type_number_t) (sizeof(vm_region_extended_info_data_t)/sizeof(int)))
  #define VM_REGION_TOP_INFO_COUNT ((mach_msg_type_number_t) (sizeof(vm_region_top_info_data_t)/sizeof(int)))
  FLAVORS = { REGION_BASIC_INFO => {:size => 30, :count => 9},
      REGION_EXTENDED_INFO => {:size => 32, :count => 9},
      REGION_TOP_INFO => {:size => 17,:count => 9}
  }

  module Pflags
    READ = 0x1 #read permission
    WRITE = 0x2 #write permission
    EXECUTE = 0x4 #execute permission
  end
end

# Memory region info base class.
# Currently Apple only supports the basic flavor. The other two flavors
# are included for completeness.
#
class Ragweed::Wraposx::RegionInfo
  def initialize(str=nil)
    refresh(str) if str
  end

  # (re)loads the data from str
  def refresh(str)
    fields = self.class.const_get :FIELDS
    # pp self.class
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

  def self.get(t, a, flavor)
    self.new(Ragweed::Wraposx::vm_region_raw(t, a, flavor))
  end

  def get(t, a)
    refresh(Ragweed::Wraposx::vm_region_raw(t, a, self.class.const_get(:FLAVOR)))
  end

  def inspect
    fields = self.class.const_get(:FIELDS)
    body = lambda do
      fields.map do |f|
        "#{f[0]}=#{send(f[0]).to_s}"
      end.join(", ")
    end
    "#<#{self.class.name.split("::").last} #{body.call}>"
  end

  def dump(&block)
    maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }      
    maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

    string =<<EOM
    -----------------------------------------------------------------------
    INFO:
    protection:       #{self.protection.to_s(2).rjust(8, "0")} #{Ragweed::Wraposx::Vm::Pflags.flag_dump(self.protection)}
    max_protection:   #{self.max_protection.to_s(2).rjust(8, "0")} #{Ragweed::Wraposx::Vm::Pflags.flag_dump(self.max_protection)}
    inheritance:      #{self.inheritance.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.inheritance)}
    shared:           #{self.shared.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.shared)}
    reserved:         #{self.reserved.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.reserved)}
    offset:           #{self.offset.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.offset)}
    behavior:         #{self.behavior.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.behavior)}
    user_wired_count: #{self.user_wired_count.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.user_wired_count)}
    size:             #{self.size.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.size)}
EOM
  end
end

class Ragweed::Wraposx::RegionBasicInfo < Ragweed::Wraposx::RegionInfo

  FLAVOR = Ragweed::Wraposx::Vm::REGION_BASIC_INFO

  (FIELDS = [ [:protection, "i"],       # The current protection for the region. 
              [:max_protection, "i"],   # The maximum protection allowed for the region.
              [:inheritance, "I"],      # The inheritance attribute for the region. 
              [:shared, "I"],           # Shared indicator. If true, the region is shared by another task. If false, the region is not shared.
              [:reserved, "I"],         # If true the region is protected from random allocation.
              [:offset, "L"],           # The region's offset into the memory object. The region begins at this offset. 
              [:behavior, "i"],         # Expected reference pattern for the memory.
              [:user_wired_count, "S"],
              [:size, "I"]              # size of memory region returned
              ]).each {|x| attr_accessor x[0]}

  def dump(&block)
    maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }      
    maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

    string =<<EOM
    -----------------------------------------------------------------------
    INFO:
    protection:       #{self.protection.to_s(2).rjust(8, "0")} #{Ragweed::Wraposx::Vm::Pflags.flag_dump(self.protection)}
    max_protection:   #{self.max_protection.to_s(2).rjust(8, "0")} #{Ragweed::Wraposx::Vm::Pflags.flag_dump(self.max_protection)}
    inheritance:      #{self.inheritance.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.inheritance)}
    shared:           #{self.shared.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.shared)}
    reserved:         #{self.reserved.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.reserved)}
    offset:           #{self.offset.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.offset)}
    behavior:         #{self.behavior.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.behavior)}
    user_wired_count: #{self.user_wired_count.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.user_wired_count)}
    size:             #{self.size.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.size)}
EOM
  end

  def self.get(t, a)
    self.new(Ragweed::Wraposx::vm_region_raw(t, a, FLAVOR))
  end
end

class Ragweed::Wraposx::RegionExtendedInfo < Ragweed::Wraposx::RegionInfo

  FLAVOR = Ragweed::Wraposx::Vm::REGION_EXTENDED_INFO
  (FIELDS = [ [:protection, "i"],
              [:user_tag, "I"],
              [:pages_resident, "I"],
              [:pages_shared_now_private, "I"],
              [:pages_swapped_out, "I"],
              [:pages_dirtied, "I"],
              [:ref_count, "I"],
              [:shadow_depth, "S"],
              [:external_pager, "C"],
              [:share_mode, "C"],
              [:size, "I"] ]).each {|x| attr_accessor x[0]}

  def dump(&block)
    maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }      
    maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

    string =<<EOM
    -----------------------------------------------------------------------
    INFO:
    protection:               #{self.protection.to_s(2).rjust(8, "0")} #{Ragweed::Wraposx::Vm::Pflags.flag_dump(self.protection)}
    user_tag:                 #{self.user_tag.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.user_tag)}
    pages_resident:           #{self.pages_resident.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.pages_resident)}
    pages_shared_now_private: #{self.pages_shared_now_private.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.pages_shared_now_private)}
    pages_swapped_out:        #{self.pages_swapped_out.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.pages_swapped_out)}
    pages_dirtied:            #{self.pages_dirtied.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.pages_dirtied)}
    ref_count:                #{self.ref_count.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.ref_count)}
    shadow_depth:             #{self.shadow_depth.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.shadow_depth)}
    external_pager:           #{self.external_pager.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.external_pager)}
    share_mode:               #{self.share_mode.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.share_mode)}
    size:                     #{self.size.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.size)}
EOM
  end

  def self.get(t, a)
    self.new(Ragweed::Wraposx::vm_region_raw(t, a, FLAVOR))
  end
end

class Ragweed::Wraposx::RegionTopInfo < Ragweed::Wraposx::RegionInfo

  FLAVOR = Ragweed::Wraposx::Vm::REGION_TOP_INFO

  (FIELDS = [ [:obj_id, "I"],
              [:ref_count, "I"],
              [:private_pages_resident, "I"],
              [:shared_pages_resident, "I"],
              [:share_mode, "C"],
              [:size, "I"]]).each {|x| attr_accessor x[0]}

  def dump(&block)
    maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
    maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

    string =<<EOM
    -----------------------------------------------------------------------
    INFO:
    obj_id:                 #{self.obj_id.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.obj_id)}
    ref_count:              #{self.ref_count.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.ref_count)}
    private_pages_resident: #{self.private_pages_resident.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.private_pages_resident)}
    shared_pages_resident:  #{self.shared_pages_resident.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.shared_pages_resident)}
    share_mode:             #{self.share_mode.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.share_mode)}
    size:                   #{self.size.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.size)}
EOM
  end

  def self.get(t, a)
    self.new(Ragweed::Wraposx::vm_region_raw(t, a, FLAVOR))
  end
end

module Ragweed::Wraposx
  class << self

    # Returns a string containing the memory region information for task
    # at address.
    # Currently Apple only supports the basic flavor. The other two flavors
    # are included for completeness.
    #
    # kern_return_t   vm_region
    #                  (vm_task_t                    target_task,
    #                   vm_address_t                     address,
    #                   vm_size_t                           size,
    #                   vm_region_flavor_t                flavor,
    #                   vm_region_info_t                    info,
    #                   mach_msg_type_number_t        info_count,
    #                   memory_object_name_t         object_name);
    def vm_region_raw(task, address, flavor)
      info = ("\x00"*64).to_ptr
      count = ([Vm::FLAVORS[flavor][:count]].pack("I_")).to_ptr
      address = ([address].pack("I_")).to_ptr
      objn = ([0].pack("I_")).to_ptr
      sz = ("\x00"*SIZEOFINT).to_ptr
      r = CALLS["libc!vm_region:IPPIPPP=I"].call(task, address, sz, Vm::FLAVORS[flavor][:count], info, count, objn).first
      raise KernelCallError.new(:vm_region, r) if r != 0
      return "#{info.to_s(Vm::FLAVORS[flavor][:size])}#{sz.to_s(SIZEOFINT)}"
    end
  end
end
