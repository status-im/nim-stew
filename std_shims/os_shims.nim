import os
export os

when defined(windows):
  import winlean
else:
  import posix

proc getCurrentProcessId*(): int =
  ## return current process ID. See also ``osproc.processID(p: Process)``.
  when defined(windows):
    proc GetCurrentProcessId(): DWORD {.stdcall, dynlib: "kernel32",
                                        importc: "GetCurrentProcessId".}
    result = GetCurrentProcessId().int
  else:
    result = getpid()

