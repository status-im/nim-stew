# This module should be globally imported from a top-level "config.nims":
#
# const stack_size {.intdefine.}: int = 0
# when defined(stack_size):
#   when defined(posix):
#     switch("import", "stew/rlimits")

{.used.}

const
  RLIMIT_STACK = 3 # from "/usr/include/bits/resource.h"
  stack_size {.intdefine.}: int = 0

## Set the stack size limit on POSIX systems (the Windows one should be set at
## compile time, using GCC options, elsewhere).
when defined(stack_size) and defined(posix) and not (defined(nimscript) or defined(js)):
  import os, posix

  var rlimit: RLimit

  if getrlimit(RLIMIT_STACK, rlimit) == -1:
    stderr.writeLine("getrlimit() error: ", osErrorMsg(osLastError()))
  else:
    rlimit.rlim_cur = stack_size
    if setrlimit(RLIMIT_STACK, rlimit) == -1:
      stderr.writeLine("setrlimit() error: ", osErrorMsg(osLastError()))
    else:
      echo "Stack size successfully limited to ", stack_size, " bytes."

