require ::File.join(::File.dirname(__FILE__),'rasm')

pushv = $VERBOSE
$VERBOSE = nil

module Ragweed::Blocks
  include Ragweed::Rasm
  extend Ragweed::Rasm

  def remote_trampoline(argc, opts={})
    i = Rasm::Subprogram.new

    # drop directly to debugger
    i << Int(3) if opts[:debug]

    # psuedo-frame-pointer
    i.<< Push(esi)
    i.<< Mov(esi, esp)

    # get the thread arg
    i.<< Add(esi, 8)

    # load it
    i.<< Mov(esi, [esi])
    i.<< Push(ebx)
    i.<< Mov(ebx, [esi])
    i.<< Push(ecx)

    # harvest arguments out of the argument buffer
    (0...argc).each do |n|
      i.<< Mov(ecx, [esi+(4+(n*4))])
      i.<< Push(ecx)
    end

    i.<< Call(ebx)

    # stuff return value after args
    i.<< Mov([esi + (4+(argc*4))], eax)
    
    # epilogue
    i.<< Pop(ecx)
    i.<< Pop(ebx)
    i.<< Pop(esi)
    i.<< Ret() # i think this is an artifact of my IRB, TODO clean up
  end
  module_function :remote_trampoline

  def event_pair_stub(opts={})
    i = Rasm::Subprogram.new

    i << Int(3) if opts[:debug]

    i.<< Push(ebp)
    i.<< Mov(ebp, esp)
    i.<< Sub(esp, 12)

    i.<< Push(esi)
    i.<< Mov(esi, [ebp+8])

    i.<< Push(eax)
    i.<< Push(ebx)
    i.<< Push(edx)
    
    # OpenProcess
    i.<< Mov(ebx, [esi]) # function ptr
    i.<< Mov(eax, [esi+24]) 
    i.<< Push(eax)
    i.<< Xor(eax, eax)
    i.<< Push(eax)
    i.<< Or(eax, 0x1F0FFF)
    i.<< Push(eax)
    i.<< Call(ebx)
    i.<< Mov([ebp-4], eax)
    
    # DuplicateHandle
    i.<< Mov(ebx, [esi+4]) # function ptr
    (1..2).each do |which|
      i.<< Push(2) # flags
      i.<< Push(0) # dunno
      i.<< Push(0) # dunno 
      i.<< Mov(edx, ebp)    # my LEA encoding is broken
      i.<< Sub(edx, 8+(4*(which-1))) 
      i.<< Lea(eax, [edx])
      i.<< Push(eax) # handle out-arg
      i.<< Xor(eax, eax)
      i.<< Not(eax)
      i.<< Push(eax) # target process
      i.<< Mov(ecx, esi)
      i.<< Add(ecx, (20 + (4 * which)))
      i.<< Push([ecx])
      i.<< Push([ebp-4]) # target process handle
      i.<< Call(ebx)
    end

    # ResetHandle
    i.<< Mov(ebx, [esi+8]) # function ptr
    (0..1).each do |which|
      i.<< Push([ebp-(8+(4*which))])
      i.<< Call(ebx)
    end

    # SignalHandle
    i.<< Mov(ebx, [esi+12]) # function ptr
    i.<< Push([ebp-8])
    i.<< Call(ebx)

    # WaitForSingleObject
    i.<< Mov(ebx, [esi+16])
    i.<< Xor(eax, eax)
    i.<< Not(eax)
    i.<< Push(eax)
    i.<< Push([ebp-12])
    i.<< Call(ebx)
 
    # All done!

    i.<< Pop(edx)
    i.<< Pop(ebx)
    i.<< Pop(eax)
    i.<< Pop(ecx)
    i.<< Pop(esi)
    i.<< Add(esp, 12)
    i.<< Pop(ebp)
    i.<< Ret()
  end
end

$VERBOSE = pushv
