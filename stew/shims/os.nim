import std/os
export os

when defined(windows):
  import winlean
else:
  import posix

when not declared(getCurrentProcessId):
  proc getCurrentProcessId*(): int =
    ## return current process ID. See also ``osproc.processID(p: Process)``.
    when defined(windows):
      proc GetCurrentProcessId(): DWORD {.stdcall, dynlib: "kernel32",
                                        importc: "GetCurrentProcessId".}
      GetCurrentProcessId().int
    else:
      getpid()

