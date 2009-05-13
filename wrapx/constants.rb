module Ragweed; end
module Ragweed::Wrapx;end
module Ragweed::Wrapx::Ptrace
  TRACE_ME = 0 # child declares it's being traced
  #(READ|WRITE)_[IDU] are not valid in OSX but defined in ptrace.h
  READ_I = 1 # read word in child's I space
  READ_D = 2 # read word in child's D space
  READ_U = 3 # read word in child's user structure
  WRITE_I = 4 # write word in child's I space
  WRITE_D = 5 # write word in child's D space
  WRITE_U = 6 # write word in child's user structure
  CONTINUE = 7 # continue the child
  KILL = 8 # kill the child process
  STEP = 9 # single step the child
  ATTACH = 10 # trace some running process
  DETACH = 11 # stop tracing a process
  SIGEXC = 12 # signals as exceptions for current_proc
  THUPDATE = 13 # signal for thread
  ATTACHEXC = 14 # attach to running process with signal exception
  FORCEQUOTA = 30 # Enforce quota for root
  DENY_ATTACH = 31 #Prevent process from being traced
  FIRSTMACH = 32 # for machine-specific requests
end

module Ragweed::Wrapx::Signal
  #the Ruby module Signal also has this information
  SIGHUP = 1 # hangup
  SIGINT = 2 # interrupt
  SIGQUIT = 3 # quit
  SIGILL = 4 # illegal instruction (not reset when caught)
  SIGTRAP = 5 # trace trap (not reset when caught)
  SIGABRT = 6 # abort()
  #if  (defined(_POSIX_C_SOURCE) && !defined(_DARWIN_C_SOURCE))
  SIGPOLL = 7 # pollable event ([XSR] generated, not supported)
  #else	/* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
  SIGIOT = SIGABRT # compatibility
  SIGEMT = 7 # EMT instruction
  #endif	/* (!_POSIX_C_SOURCE || _DARWIN_C_SOURCE) */
  SIGFPE = 8 # floating point exception
  SIGKILL = 9 # kill (cannot be caught or ignored)
  SIGBUS = 10 # bus error
  SIGSEGV = 11 # segmentation violation
  SIGSYS = 12 # bad argument to system call
  SIGPIPE = 13 # write on a pipe with no one to read it
  SIGALRM = 14 # alarm clock
  SIGTERM = 15 # software termination signal from kill
  SIGURG = 16 # urgent condition on IO channel
  SIGSTOP = 17 # sendable stop signal not from tty
  SIGTSTP = 18 # stop signal from tty
  SIGCONT = 19 # continue a stopped process
  SIGCHLD = 20 # to parent on child stop or exit
  SIGTTIN = 21 # to readers pgrp upon background tty read
  SIGTTOU = 22 # like TTIN for output if (tp->t_local&LTOSTOP)
  #if  (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
  SIGIO = 23 # input/output possible signal
  #endif
  SIGXCPU = 24 # exceeded CPU time limit
  SIGXFSZ = 25 # exceeded file size limit
  SIGVTALRM = 26 # virtual time alarm
  SIGPROF = 27 # profiling time alarm
  #if  (!defined(_POSIX_C_SOURCE) || defined(_DARWIN_C_SOURCE))
  SIGWINCH = 28 # window size changes
  SIGINFO = 29 # information request
  #endif
  SIGUSR1 = 30 # user defined signal 1
  SIGUSR2 = 31 # user defined signal 2
end

module Ragweed::Wrapx::Wait
  NOHANG = 0x01 # [XSI] no hang in wait/no child to reap
  UNTRACED = 0x02 # [XSI] notify on stop, untraced child
  EXITED = 0x04 # [XSI] Processes which have exitted
  STOPPED = 0x08 # [XSI] Any child stopped by signal
  CONTINUED = 0x10 # [XSI] Any child stopped then continued
  NOWWAIT = 0x20 # [XSI] Leave process returned waitable
end

module Ragweed::Wrapx::Vm; end
module Ragweed::Wrapx::Vm::Prot
  #vm_protect permission flags for memory spaces
  READ = 0x1 #read permission
  WRITE = 0x2 #write permission
  EXECUTE = 0x4 #execute permission
  NONE = 0x0 #no rights
  ALL = 0x7 #all permissions
end

module Ragweed::Wrapx::Dl
  RTLD_LAZY = 0x1
  RTLD_NOW = 0x2
  RTLD_LOCAL = 0x4
  RTLD_GLOBAL = 0x8
  RTLD_NOLOAD = 0x10
  RTLD_NODELETE = 0x80
  RTLD_FIRST = 0x100	#/* Mac OS X 10.5 and later */

  # Special handle arguments for dlsym().
  #define RTLD_NEXT		((void *) -1)	/* Search subsequent objects. */
  #define	RTLD_DEFAULT	((void *) -2)	/* Use default search algorithm. */
  #define	RTLD_SELF		((void *) -3)	/* Search this and subsequent objects (Mac OS X 10.5 and later) */
end
