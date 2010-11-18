# miscelaneous structs needed for other calls/structures

module Ragweed; end
module Ragweed::Wraposx
  class FpControl < FFI::Struct
    layout :value, :ushort
    
    def invalid
      self.value >> 15
    end
    def denorm
      (self.value >> 14) & 1
    end
    def zdiv
      (self.value >> 13) & 1
    end
    def ovrfl
      (self.value >> 12) & 1
    end
    def undfl
      (self.value >> 11) & 1
    end
    def precis
      (self.value >> 10) & 1
    end
    def res0
      (self.value >> 8) & 3
    end
    def pc
      (self.value >> 6) & 3
    end
    def rc
      (self.value >> 4) & 3
    end
    def res1
      (self.value >> 3) & 1
    end
    def res2
      self.value & 7
    end
  end
  
  class FpStatus < FFI::Struct
    layout :value, :ushort
    def invalid
      self.value >> 15
    end
    def denorm
      (self.value >> 14) & 1
    end
    def zdiv
      (self.value >> 13) & 1
    end
    def ovrfl
      (self.value >> 12) & 1
    end
    def undfl
      (self.value >> 11) & 1
    end
    def precis
      (self.value >> 10) & 1
    end
    def stkflt
      (self.value >> 9) & 1
    end
    def errsumm
      (self.value >> 8) & 1
    end
    def c0
      (self.value >> 7) & 1
    end
    def c1
      (self.value >> 6) & 1
    end
    def c2
      (self.value >> 5) & 1
    end
    def tos
      (self.value >> 2) & 7
    end
    def c2
      (self.value >> 1) & 1
    end
    def busy
      self.value & 1
    end
  end

  class MmstReg < FFI::Struct
    layout :mmst_reg, [:char, 10],
           :mmst_rsrv, [:char, 6]
  end

  class XmmReg < FFI::Struct
    layout :xmm_reg, [:char, 16]
  end
  
  class TimeValue < FFI::Struct
    layout :seconds, :int,
           :microseconds, :int
  end
end
