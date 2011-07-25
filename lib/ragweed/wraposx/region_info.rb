module Ragweed; end
module Ragweed::Wraposx; end
module Ragweed::Wraposx::Vm
  # these are flavor arguments for vm_region
  # only basic info is supported by apple
  REGION_BASIC_INFO_64 = 9
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

  module Pflags
    READ = 0x1 #read permission
    WRITE = 0x2 #write permission
    EXECUTE = 0x4 #execute permission
  end

  # Memory region info base class.
  #
  class RegionInfo < FFI::Struct
    include Ragweed::FFIStructInclude
    attr_accessor :region_size
    attr_accessor :base_address
  end

  class RegionBasicInfo < RegionInfo
    FLAVOR = Ragweed::Wraposx::Vm::REGION_BASIC_INFO

    layout :protection, Ragweed::Wraposx::Libc.find_type(:vm_prot_t),
           :max_protection, Ragweed::Wraposx::Libc.find_type(:vm_prot_t),
           :inheritance, Ragweed::Wraposx::Libc.find_type(:vm_inherit_t),
           :shared, Ragweed::Wraposx::Libc.find_type(:boolean_t),
           :reserved, Ragweed::Wraposx::Libc.find_type(:boolean_t),
           :offset, :uint32,
           :behavior, Ragweed::Wraposx::Libc.find_type(:vm_behavior_t),
           :user_wired_count, :ushort


    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }      
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      BASIC INFO:
      base address:     #{self.base_address.to_s(16).rjust(8, "0")}
    
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

  class RegionBasicInfo64 < RegionInfo
    FLAVOR = Ragweed::Wraposx::Vm::REGION_BASIC_INFO_64

    layout :protection, Ragweed::Wraposx::Libc.find_type(:vm_prot_t),
           :max_protection, Ragweed::Wraposx::Libc.find_type(:vm_prot_t),
           :inheritance, Ragweed::Wraposx::Libc.find_type(:vm_inherit_t),
           :shared, Ragweed::Wraposx::Libc.find_type(:boolean_t),
           :reserved, Ragweed::Wraposx::Libc.find_type(:boolean_t),
           :offset, Ragweed::Wraposx::Libc.find_type(:memory_object_offset_t),
           :behavior, Ragweed::Wraposx::Libc.find_type(:vm_behavior_t),
           :user_wired_count, :ushort

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }      
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      BASIC INFO:
      base address:     #{self.base_address.to_s(16).rjust(8, "0")}
    
      protection:       #{self.protection.to_s(2).rjust(8, "0")} #{Ragweed::Wraposx::Vm::Pflags.flag_dump(self.protection)}
      max_protection:   #{self.max_protection.to_s(2).rjust(8, "0")} #{Ragweed::Wraposx::Vm::Pflags.flag_dump(self.max_protection)}
      inheritance:      #{self.inheritance.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.inheritance)}
      shared:           #{self.shared.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.shared)}
      reserved:         #{self.reserved.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.reserved)}
      offset:           #{self.offset.to_s(16).rjust(16, "0")} #{maybe_hex.call(self.offset)}
      behavior:         #{self.behavior.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.behavior)}
      user_wired_count: #{self.user_wired_count.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.user_wired_count)}
      size:             #{self.size.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.size)}
EOM
    end
  end

  # struct vm_region_extended_info {
  #         vm_prot_t               protection;
  #         unsigned int            user_tag;
  #         unsigned int            pages_resident;
  #         unsigned int            pages_shared_now_private;
  #         unsigned int            pages_swapped_out;
  #         unsigned int            pages_dirtied;
  #         unsigned int            ref_count;
  #         unsigned short          shadow_depth;
  #         unsigned char           external_pager;
  #         unsigned char           share_mode;
  # };
  class RegionExtendedInfo < RegionInfo
    FLAVOR = Ragweed::Wraposx::Vm::REGION_EXTENDED_INFO

    layout :protection, Ragweed::Wraposx::Libc.find_type(:vm_prot_t),
           :user_tag, :uint,
           :pages_resident, :uint,
           :pages_shared_now_private, :uint,
           :pages_swapped_out, :uint,
           :pages_dirtied, :uint,
           :ref_count, :uint,
           :shadow_depth, :ushort,
           :external_pager, :uchar,
           :share_mode, :uchar

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }      
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      EXTENDED INFO:
      base address:             #{self.base_address.to_s(16).rjust(8, "0")}
    
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
  end

  # struct vm_region_top_info {
  #         unsigned int            obj_id;
  #         unsigned int            ref_count;
  #         unsigned int            private_pages_resident;
  #         unsigned int            shared_pages_resident;
  #         unsigned char           share_mode;
  # };
  class RegionTopInfo < RegionInfo
    FLAVOR = Ragweed::Wraposx::Vm::REGION_TOP_INFO

    layout :obj_id, :uint,
           :ref_count, :uint,
           :private_pages_resident, :uint,
           :shared_pages_resident, :uint,
           :share_mode, :uchar

    def dump(&block)
      maybe_hex = lambda {|a| begin; "\n" + (" " * 9) + block.call(a, 16).hexdump(true)[10..-2]; rescue; ""; end }
      maybe_dis = lambda {|a| begin; "\n" + block.call(a, 16).distorm.map {|i| "         " + i.mnem}.join("\n"); rescue; ""; end }

      string =<<EOM
      -----------------------------------------------------------------------
      TOP INFO:
      base address:           #{self.base_address.to_s(16).rjust(8, "0")}
    
      obj_id:                 #{self.obj_id.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.obj_id)}
      ref_count:              #{self.ref_count.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.ref_count)}
      private_pages_resident: #{self.private_pages_resident.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.private_pages_resident)}
      shared_pages_resident:  #{self.shared_pages_resident.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.shared_pages_resident)}
      share_mode:             #{self.share_mode.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.share_mode)}
      size:                   #{self.size.to_s(16).rjust(8, "0")} #{maybe_hex.call(self.size)}
EOM
    end
  end

  # define VM_REGION_BASIC_INFO_COUNT ((mach_msg_type_number_t) (sizeof(vm_region_basic_info_data_t)/sizeof(int)))
  # define VM_REGION_BASIC_INFO_COUNT_64 ((mach_msg_type_number_t) (sizeof(vm_region_basic_info_data_64_t)/sizeof(int)))
  # define VM_REGION_EXTENDED_INFO_COUNT   ((mach_msg_type_number_t) (sizeof(vm_region_extended_info_data_t)/sizeof(int)))
  # define VM_REGION_TOP_INFO_COUNT ((mach_msg_type_number_t) (sizeof(vm_region_top_info_data_t)/sizeof(int)))
  FLAVORS = { REGION_BASIC_INFO => {:size => 30, :count => 8, :class => RegionBasicInfo},
      REGION_BASIC_INFO_64 => {:size => 30, :count => 9, :class => RegionBasicInfo64},
      REGION_EXTENDED_INFO => {:size => 32, :count => 8, :class => RegionExtendedInfo},
      REGION_TOP_INFO => {:size => 17,:count => 5, :class => RegionTopInfo}
  }
end

module Ragweed::Wraposx
  module Libc
    extend FFI::Library
    ffi_lib FFI::Library::LIBC
    
    # determine if a function is defined in the attached libraries
    def self.find_function func
      ffi_libraries.detect{|lib| lib.find_function(func)}
    end

    attach_function :vm_region, [:vm_map_t, :pointer, :pointer, :vm_region_flavor_t, :pointer, :pointer, :pointer], :int if find_function "vm_region"
    attach_function :vm_region_64, [:vm_map_t, :pointer, :pointer, :vm_region_flavor_t, :pointer, :pointer, :pointer], :int if find_function "vm_region_64"
  end

  class << self

    # Returns the base address, size, and a pointer to the requested information
    # about the memory region at address in the target_task.
    #
    # Currently, only VM_REGION_BASIC_INFO is supported by Apple.
    # Unless this is being run in 32bits, use vm_region_64 instead.
    #
    # kern_return_t   vm_region
    #                  (vm_map_t                   target_task,
    #                   vm_address_t                  *address,
    #                   vm_size_t                        *size,
    #                   vm_region_flavor_t              flavor,
    #                   vm_region_info_t                  info,
    #                   mach_msg_type_number_t     *info_count,
    #                   mach_port_t               *object_name);
    def vm_region(task, addr, flavor)
      info = FFI::MemoryPointer.new(Vm::FLAVORS[flavor][:class], 1)
      count = FFI::MemoryPointer.new(:int, 1).write_int(Vm::FLAVORS[flavor][:count])
      address = FFI::MemoryPointer.new(Libc.find_type(:vm_address_t), 1).write_ulong(addr)
      sz = FFI::MemoryPointer.new(Libc.find_type(:vm_size_t), 1)
      objn = FFI::MemoryPointer.new(Libc.find_type(:mach_port_t), 1)
      
      r = Libc.vm_region(task, address, sz, flavor, info, count, objn)
      raise KernelCallError.new(:vm_region, r) if r != 0
      ret = Vm::Flavors[flavor][:class].new info
      ret.region_size = size.read_ulong
      ret.base_address = address.read_ulong
      ret
    end if Libc.find_function "vm_region"

    # Returns the base address, size, and a pointer to the requested information
    # about the memory region at address in the target_task.
    #
    # Currently, only VM_REGION_BASIC_INFO is supported by Apple.
    #
    # kern_return_t   vm_region
    #                  (vm_map_t                   target_task,
    #                   vm_address_t                  *address,
    #                   vm_size_t                        *size,
    #                   vm_region_flavor_t              flavor,
    #                   vm_region_info_t                  info,
    #                   mach_msg_type_number_t     *info_count,
    #                   mach_port_t               *object_name);
    def vm_region_64(task, addr, flavor)
      # OSX does this as well, so we need to do it ourselves
      flavor = Vm::REGION_BASIC_INFO_64 if flavor == Vm::REGION_BASIC_INFO
      info = FFI::MemoryPointer.new(Vm::FLAVORS[flavor][:class])
      count = FFI::MemoryPointer.new(Libc.find_type(:mach_msg_type_number_t), 1).write_uint(Vm::FLAVORS[flavor][:count])
      address = FFI::MemoryPointer.new(Libc.find_type(:vm_address_t), 1).write_ulong(addr)
      sz = FFI::MemoryPointer.new(Libc.find_type(:vm_size_t), 1)
      objn = FFI::MemoryPointer.new(Libc.find_type(:mach_port_t), 1)
      
      r = Libc.vm_region_64(task, address, sz, flavor, info, count, objn)
      raise KernelCallError.new(:vm_region_64, r) if r != 0
      ret = Vm::FLAVORS[flavor][:class].new info
      ret.region_size = sz.read_ulong
      ret.base_address = address.read_ulong
      ret
    end if Libc.find_function "vm_region_64"
  end
end
