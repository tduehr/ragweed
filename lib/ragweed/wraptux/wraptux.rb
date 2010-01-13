require 'dl'

module Ragweed; end
module Ragweed::Wraptux
  LIBS = Hash.new do |h, str|
    if not str =~ /^[\.\/].*/
      str = "/lib/" + str
    end
    if not str =~ /.*\.so.6$/
      str = str + ".so.6"
    end
    h[str] = DL.dlopen(str)
  end

  CALLS = Hash.new do |h, str|
    lib = proc = args = ret = nil
    lib, rest = str.split "!"
    proc, rest = rest.split ":"
    args, ret = rest.split("=") if rest
    ret ||= "0"
    raise "need proc" if not proc
    h[str] = LIBS[lib][proc, ret + args]
  end

  NULL = DL::PtrData.new(0)

  SIZEOFINT = DL.sizeof('I')
  SIZEOFLONG = DL.sizeof('L')

  class << self
    #long ptrace(enum __ptrace_request request, pid_t pid, void *addr, void *data);
    def ptrace(request, pid, addr, data)
      DL.last_error = 0
      r = CALLS["libc!ptrace:IIII=I"].call(request, pid, addr, data).first
      raise SystemCallError.new("ptrace", DL.last_error) if r == -1 and DL.last_error != 0
      return r
    end

    def malloc(sz)
      r = CALLS["libc!malloc:L=L"].call(sz)
      return r
    end

    #wait(int *status);
    def wait
      status = ("\x00"*SIZEOFINT).to_ptr.to_i
      r = CALLS["libc!wait:I=I"].call(status).first
      raise SystemCallError.new("wait", DL.last_error) if r == -1
      self.continue # continue with the ptrace at this point
      return status.to_s(SIZEOFINT).unpack('i_').first
    end

    #waitpid(pid_t pid, int *stat_loc, int options);
    def waitpid(pid, opt=1)
      pstatus = ("\x00"*SIZEOFINT).to_ptr
      r = CALLS["libc!waitpid:IPI=I"].call(pid, pstatus, opt).first
      raise SystemCallError.new("waitpid", DL.last_error) if r == -1
      return [r, pstatus.to_s(SIZEOFINT).unpack('i_').first]
    end

    #kill(pid_t pid, int sig);
    def kill(pid, sig)
      DL.last_error = 0
      r = CALLS["libc!kill:II=I"].call(pid,sig).first
      raise SystemCallError.new("kill",DL.last_error) if r != 0
    end

    def getpid
      CALLS["libc!getpid:=I"].call.first
    end
  end
end
