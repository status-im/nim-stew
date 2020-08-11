import results
export results

when defined(windows):
  const
    GENERIC_READ = 0x80000000'u32
    GENERIC_WRITE = 0x40000000'u32

    CREATE_NEW = 1'u32
    CREATE_ALWAYS = 2'u32
    OPEN_EXISTING = 3'u32
    OPEN_ALWAYS = 4'u32
    TRUNCATE_EXISTING = 5'u32

    FILE_FLAG_OVERLAPPED = 0x40000000'u32
    FILE_FLAG_NO_BUFFERING = 0x20000000'u32
    FILE_SHARE_READ = 1'u32
    FILE_ATTRIBUTE_READONLY = 0x00000001'u32
    FILE_ATTRIBUTE_DIRECTORY = 0x00000010'u32

    INVALID_HANDLE_VALUE = cast[uint](-1)
    INVALID_FILE_ATTRIBUTES = cast[uint32](-1)
    MAX_PATH = 260

  type
    SafeIoErrCode* = distinct uint32
    SafeIoHandle* = distinct uint

    SECURITY_ATTRIBUTES {.final, pure.} = object
      nLength: uint32
      lpSecurityDescriptor: pointer
      bInheritHandle: int32

  const
    ERROR_ALREADY_EXISTS = 183'u32

  proc getLastError(): uint32 {.
       importc: "GetLastError", stdcall, dynlib: "kernel32", sideEffect.}
  proc createDirectoryW(pathName: WideCString,
                        security: var SECURITY_ATTRIBUTES): int32 {.
       importc: "CreateDirectoryW", dynlib: "kernel32", stdcall, sideEffect.}
  proc removeDirectoryW(pathName: WideCString): int32 {.
       importc: "RemoveDirectoryW", dynlib: "kernel32", stdcall, sideEffect.}
  proc createFileW(fileName: WideCString, dwDesiredAccess: uint32,
                   dwShareMode: uint32, security: var SECURITY_ATTRIBUTES,
                   dwCreationDisposition: uint32, dwFlagsAndAttributes: uint32,
                   hTemplateFile: uint): uint {.
       importc: "CreateFileW", dynlib: "kernel32", stdcall, sideEffect.}
  proc closeHandle(hobj: uint): int32 {.
       importc: "CloseHandle", dynlib: "kernel32", stdcall, sideEffect.}
  proc writeFile(hFile: uint32, lpBuffer: pointer,
                 nNumberOfBytesToWrite: uint32,
                 lpNumberOfBytesWritten: var uint32,
                 lpOverlapped: pointer): int32 {.
       importc: "WriteFile", dynlib: "kernel32", stdcall, sideEffect.}
  proc readFile(hFile: uint32, lpBuffer: pointer,
                nNumberOfBytesToRead: uint32,
                lpNumberOfBytesRead: var uint32,
                lpOverlapped: pointer): int32 {.
       importc: "ReadFile", dynlib: "kernel32", stdcall, sideEffect.}
  proc getFileAttributes(path: WideCString): uint32 {.
       importc: "GetFileAttributesW", dynlib: "kernel32", stdcall, sideEffect.}
  proc getCurrentDirectoryW(nBufferLength: uint32,
                            lpBuffer: WideCString): uint32 {.
       importc: "GetCurrentDirectoryW", dynlib: "kernel32", stdcall,
       sideEffect.}

  proc `==`*(a: SafeIoErrCode, b: uint32): bool {.inline.} =
    (uint32(a) == b)

else:
  import posix

  type
    SafeIoHandle* = distinct cint
    SafeIoErrCode* = distinct cint

  when defined(linux):
    const
      O_DIRECT = cint(0x4000)
      O_CLOEXEC = cint(0x2000000)
  elif defined(freebsd):
    const
      O_DIRECT = cint(0x10000)
      O_CLOEXEC = cint(0x100000)
  elif defined(dragonflybsd):
    const
      O_DIRECT = cint(0x10000)
      O_CLOEXEC = cint(0x20000)
  elif defined(netbsd):
    const
      O_DIRECT = cint(0x80000)
      O_CLOEXEC = cint(0x400000)
  elif defined(openbsd):
    const
      O_CLOEXEC = cint(0x10000)
  elif defined(macosx):
    const
      O_CLOEXEC = cint(0x1000000)
      F_NOCACHE = cint(48)

  proc write*(a1: cint, a2: pointer, a3: csize_t): int {.
       importc, header: "<unistd.h>".}
  proc read*(a1: cint, a2: pointer, a3: csize_t): int {.
       importc, header: "<unistd.h>".}
  proc c_strlen(a: cstring): cint {.
    importc: "strlen", header: "<string.h>", noSideEffect.}

  proc `==`*(a: SafeIoErrCode, b: cint): bool {.inline.} =
    (cint(a) == b)

type
  SafeIoError*[T] = Result[T, SafeIoErrCode]

  OpenFlags* = enum
    ReadOnly, WriteOnly, ReadWrite, Create, Exclusive, Append, Truncate,
    NoInherit, NonBlock, Direct

  AccessFlags* = enum
    Find, Read, Write, Execute

{.push stackTrace:off.}
proc ioLastError*(): SafeIoErrCode {.sideEffect.} =
  ## Retrieves the last operating system error code.
  ##
  ## **Warning**:
  ## The behaviour of this procedure varies between Windows and POSIX systems.
  ## On Windows some OS calls can reset the error code to ``0`` causing this
  ## procedure to return ``0``. It is therefore advised to call this procedure
  ## immediately after an OS call fails. On POSIX systems this is not a problem.
  when defined(nimscript):
    discard
  elif defined(windows):
    SafeIoErrCode(getLastError())
  else:
    SafeIoErrCode(errno)
{.pop.}

proc `==`*(a, b: SafeIoErrCode): bool {.borrow.}
proc `$`*(a: SafeIoErrCode): string {.borrow.}

proc getCurrentDir*(): SafeIoError[string] =
  ## Returns string containing an absolute pathname that is the current working
  ## directory of the calling process.
  when defined(posix):
    var bufsize = 1024
    var buffer = newString(bufsize)
    while true:
      if posix.getcwd(buffer, bufsize) != nil:
        buffer.setLen(c_strlen(buffer))
        return ok(buffer)
      else:
        let errCode = ioLastError()
        if errCode == EINTR:
          continue
        elif errCode == ERANGE:
          bufsize = bufsize shl 1
          buffer = newString(bufsize)
        else:
          return err(errCode)
  elif defined(windows):
    var bufsize = uint32(MAX_PATH)
    var buffer = newWideCString("", int(bufsize))
    while true:
      let res = getCurrentDirectoryW(bufsize, buffer)
      if res == 0'u32:
        return err(ioLastError())
      elif res > bufsize:
        buffer = newWideCString("", int(res))
        bufsize = res
      else:
        return ok(buffer$int(res))

proc createDir*(dir: string, mode: int = 0o777): SafeIoError[bool] =
  ## Attempts to create a directory named ``dir``.
  ##
  ## The argument ``mode`` specifies the mode for the new directory.
  ## It is modified by the process's umask in the usual way: in the absence of
  ## a default ACL, the mode of the created directory is
  ## (mode and not(umask) and 0o777). Whether other mode bits are honored for
  ## the created directory depends on the operating system.
  ##
  ## Returns ``true`` if directory was successfully created and ``false`` if
  ## path ``dir`` is already exists.
  when defined(posix):
    when defined(solaris):
      let existFlags = {EEXIST, ENOSYS}
    elif defined(haiku):
      let existFlags = {EEXIST, EROFS}
    else:
      let existFlags = {EEXIST}
    while true:
      let res = posix.mkdir(cstring(dir), Mode(mode))
      if res == 0'i32:
        return ok(true)
      else:
        let errCode = ioLastError()
        if cint(errCode) in existFlags:
          return ok(false)
        elif errCode == EINTR:
          continue
        else:
          return err(errCode)
  elif defined(windows):
    var sa = SECURITY_ATTRIBUTES(
      nLength: uint32(sizeof(SECURITY_ATTRIBUTES)),
      bInheritHandle: 0
    )
    let res = createDirectoryW(newWideCString(dir), sa)
    if res != 0'i32:
      ok(true)
    else:
      let errCode = ioLastError()
      if errCode == ERROR_ALREADY_EXISTS:
        ok(false)
      else:
        err(errCode)

proc removeDir*(dir: string): SafeIoError[void] =
  ## Deletes a directory, which must be empty.
  when defined(posix):
    while true:
      let res = posix.rmdir(cstring(dir))
      if res == 0:
        return ok()
      else:
        let errCode = ioLastError()
        if errCode == EINTR:
          continue
        else:
          return err(errCode)
  elif defined(windows):
    let res = removeDirectoryW(newWideCString(dir))
    if res != 0'i32:
      ok()
    else:
      err(ioLastError())

proc isFile*(path: string): bool =
  ## Returns ``true`` if ``path`` exists and is a regular file or symlink.
  when defined(posix):
    var a: posix.Stat
    let res = posix.stat(path, a)
    if res == -1:
      false
    else:
      posix.S_ISREG(a.st_mode)
  elif defined(windows):
    let res = getFileAttributes(newWideCString(path))
    if res == INVALID_FILE_ATTRIBUTES:
      false
    else:
      (res and FILE_ATTRIBUTE_DIRECTORY) == 0'u32

proc isDir*(path: string): bool =
  ## Returns ``true`` if ``path`` exists and is a directory.
  when defined(posix):
    var a: posix.Stat
    let res = posix.stat(path, a)
    if res == -1:
      false
    else:
      posix.S_ISDIR(a.st_mode)
  elif defined(windows):
    let res = getFileAttributes(newWideCString(path))
    if res == INVALID_FILE_ATTRIBUTES:
      false
    else:
      (res and FILE_ATTRIBUTE_DIRECTORY) == FILE_ATTRIBUTE_DIRECTORY

proc createPath*(path: string): SafeIoError[void] =
  when defined(posix):
    var paths: seq[string]
    var curpath = path
    var curbase, curdir: string
    while true:
      var curbase = $posix.basename(cstring(curpath))
      var curdir = $posix.dirname(cstring(curpath))
      echo curdir
      if curdir == "/":
        curpath = "/" & curbase
        paths.add(curpath)
        break
      else:
        curpath = curdir & "/" & curbase
        paths.add(curpath)
        curpath = curdir

    echo paths

proc removePath*(path: string): SafeIoError[void] =
  discard

proc openFile*(pathName: string, flags: set[OpenFlags],
               createMode: int = 0o666): SafeIoError[SafeIoHandle] =
  when defined(posix):
    var cflags: cint
    if OpenFlags.ReadOnly in flags:
      cflags = cflags or posix.O_RDONLY
    if OpenFlags.WriteOnly in flags:
      cflags = cflags or posix.O_WRONLY
    if OpenFlags.ReadWrite in flags:
      cflags = cflags or posix.O_RDWR
    if OpenFlags.Create in flags:
      cflags = cflags or posix.O_CREAT
    if OpenFlags.Exclusive in flags:
      cflags = cflags or posix.O_EXCL
    if OpenFlags.Truncate in flags:
      cflags = cflags or posix.O_TRUNC
    if OpenFlags.Append in flags:
      cflags = cflags or posix.O_APPEND
    when defined(linux) or defined(freebsd) or defined(netbsd) or
         defined(dragonflybsd):
      if OpenFlags.Direct in flags:
        cflags = cflags or O_DIRECT
    if OpenFlags.NoInherit in flags:
      cflags = cflags or O_CLOEXEC
    if OpenFlags.NonBlock in flags:
      cflags = cflags or posix.O_NONBLOCK

    while true:
      let ores = posix.open(cstring(pathName), cflags, Mode(createMode))
      if ores == -1:
        let errCode = ioLastError()
        if errCode == EINTR:
          continue
        else:
          return err(errCode)
      else:
        when defined(macosx):
          if OpenFlags.Direct in flags:
            while true:
              let fres = posix.fcntl(cint(ores), F_NOCACHE, 1)
              if fres == -1:
                let errCode = ioLastError()
                if errCode == EINTR:
                  continue
                else:
                  return err(errCode)
              else:
                return ok(SafeIoHandle(ores))
          else:
            return ok(SafeIoHandle(ores))
        else:
          return ok(SafeIoHandle(ores))
  elif defined(windows):
    var
      dwAccess: uint32
      dwShareMode: uint32
      dwCreation: uint32
      dwFlags: uint32

    var sa = SECURITY_ATTRIBUTES(
      nLength: uint32(sizeof(SECURITY_ATTRIBUTES)),
      bInheritHandle: 1
    )

    if OpenFlags.WriteOnly in flags:
      dwAccess = dwAccess or GENERIC_WRITE
    elif OpenFlags.ReadWrite in flags:
      dwAccess = dwAccess or (GENERIC_WRITE or GENERIC_READ)
    else:
      dwAccess = dwAccess or GENERIC_READ

    if {OpenFlags.Create, OpenFlags.Exclusive} <= flags:
      dwCreation = dwCreation or CREATE_NEW
    elif OpenFlags.Truncate in flags:
      if OpenFlags.Create in flags:
        dwCreation = dwCreation or CREATE_ALWAYS
      elif OpenFlags.ReadOnly notin flags:
        dwCreation = dwCreation or TRUNCATE_EXISTING
    elif OpenFlags.Append in flags:
      dwCreation = dwCreation or OPEN_EXISTING
    elif OpenFlags.Create in flags:
      dwCreation = dwCreation or OPEN_ALWAYS
    else:
      dwCreation = dwCreation or OPEN_EXISTING

    if dwCreation == OPEN_EXISTING and
       ((dwAccess and (GENERIC_READ or GENERIC_WRITE)) == GENERIC_READ):
      dwShareMode = dwShareMode or FILE_SHARE_READ

    if OpenFlags.NonBlock in flags:
      dwFlags = dwFlags or FILE_FLAG_OVERLAPPED
    if OpenFlags.Direct in flags:
      dwFlags = dwFlags or FILE_FLAG_NO_BUFFERING
    if OpenFlags.NoInherit in flags:
      sa.bInheritHandle = 0

    let res = createFileW(newWideCString(pathName), dwAccess, dwShareMode,
                          sa, dwCreation, dwFlags, 0'u32)
    if res == INVALID_HANDLE_VALUE:
      err(ioLastError())
    else:
      ok(SafeIoHandle(res))
proc closeFile*(handle: SafeIoHandle): SafeIoError[void] =
  when defined(windows):
    let res = closeHandle(uint(handle))
    if res == 0:
      err(ioLastError())
    else:
      ok()
  elif defined(posix):
    let res = posix.close(cint(handle))
    if res == -1:
      err(ioLastError())
    else:
      ok()

proc writeFile*(handle: SafeIoHandle,
                data: openarray[byte]): SafeIoError[uint] =
  when defined(posix):
    if len(data) > 0:
      while true:
        let res = write(cint(handle), unsafeAddr data[0], csize_t(len(data)))
        if res == -1:
          let errCode = ioLastError()
          if errCode == EINTR:
            continue
          else:
            return err(errCode)
        else:
          return ok(uint(res))
    else:
      return ok(0)
  elif defined(windows):
    if len(data) > 0:
      var lpNumberOfBytesWritten = 0'u32
      let res = writeFile(uint32(handle), unsafeAddr data[0], uint32(len(data)),
                          lpNumberOfBytesWritten, nil)
      if res != 0:
        ok(lpNumberOfBytesWritten)
      else:
        err(ioLastError())
    else:
      ok(0)

proc writeFile*(handle: SafeIoHandle,
                data: openarray[char]): SafeIoError[uint] {.inline.} =
  writeFile(handle, data.toOpenArrayByte(0, len(data) - 1))

proc readFile*(handle: SafeIoHandle,
               data: var openarray[byte]): SafeIoError[uint] =
  when defined(posix):
    if len(data) > 0:
      while true:
        let res = read(cint(handle), unsafeAddr data[0], csize_t(len(data)))
        if res == -1:
          let errCode = ioLastError()
          if errCode == EINTR:
            continue
          else:
            return err(errCode)
        else:
          return ok(uint(res))
    else:
      return ok(0)
  elif defined(windows):
    if len(data) > 0:
      var lpNumberOfBytesRead = 0'u32
      let res = readFile(uint32(handle), unsafeAddr data[0], uint32(len(data)),
                         lpNumberOfBytesRead, nil)
      if res != 0:
        ok(lpNumberOfBytesRead)
      else:
        err(ioLastError())
    else:
      ok(0)

proc readFile*(handle: SafeIoHandle,
               data: var openarray[char]): SafeIoError[uint] =
  readFile(handle, data.toOpenArrayByte(0, len(data) - 1))

proc writeFile*(pathName: string, data: openarray[byte],
                createMode: int = 0o666): SafeIoError[void] =
  let flags = {OpenFlags.WriteOnly, OpenFlags.Truncate, OpenFlags.Create}
  let handle = ? openFile(pathName, flags, createMode)
  var offset = 0
  while offset < len(data):
    let res = writeFile(handle, data.toOpenArray(offset, len(data) - 1))
    if res.isErr():
      # Do not care about `closeFile(handle)` error because we already in
      # error handler.
      discard closeFile(handle)
      return err(res.error)
    else:
      offset = offset + int(res.get())
  ? closeFile(handle)
  ok()

proc writeFile*(pathName: string, data: openarray[char],
                createMode: int = 0o666): SafeIoError[void] =
  writeFile(pathName, data.toOpenArrayByte(0, len(data) - 1), createMode)

proc readFile*(pathName: string, blockSize = 16384'u): SafeIoError[seq[byte]] =
  doAssert(blockSize > 0, "blockSize must not be zero")
  let flags = {OpenFlags.ReadOnly}
  let handle = ? openFile(pathName, flags)
  var offset = 0
  var buffer = newSeq[byte](blockSize)
  while true:
    let res = readFile(handle, buffer.toOpenArray(offset, len(buffer) - 1))
    if res.isErr():
      # Do not care about `closeFile(handle)` error because we already in
      # error handler.
      discard closeFile(handle)
      return err(res.error)
    else:
      offset = offset + int(res.get())
      if res.get() != blockSize:
        buffer.setLen(offset)
        ? closeFile(handle)
        return ok(buffer)
      else:
        buffer.setLen(len(buffer) + int(blockSize))

proc fileAccessible*(pathName: string, mask: set[AccessFlags]): bool =
  when defined(posix):
    var mode: cint
    if AccessFlags.Find in mask:
      mode = mode or posix.F_OK
    if AccessFlags.Read in mask:
      mode = mode or posix.R_OK
    if AccessFlags.Write in mask:
      mode = mode or posix.W_OK
    if AccessFlags.Execute in mask:
      mode = mode or posix.X_OK
    let res = posix.access(cstring(pathName), mode)
    if res == 0:
      true
    else:
      false
  elif defined(windows):
    let res = getFileAttributes(newWideCString(pathName))
    if res == INVALID_FILE_ATTRIBUTES:
      return false
    if AccessFlags.Write in mask:
      if (res and FILE_ATTRIBUTE_READONLY) == FILE_ATTRIBUTE_READONLY:
        return false
      else:
        return true
    return true

proc checkPermissions*(pathName: string, mask: int): bool =
  when defined(windows):
    true
  else:
    var a: posix.Stat
    let res = posix.stat(pathName, a)
    if res == 0:
      (int(a.st_mode) and 0o777) == mask
    else:
      false

when isMainModule:
  echo getCurrentDir()
  echo createPath(getCurrentDir().tryGet() & "/testdir")
  echo repr writeFile("some.private.key", "TEST", 0o640)
  echo checkPermissions("some.private.key", 0o640)
  echo checkPermissions("some.private.key", 0o600)
  echo fileAccessible("some.private.key", {AccessFlags.Read, AccessFlags.Write})
  echo fileAccessible("some.private.key", {AccessFlags.Execute})
  echo repr readFile("some.private.key")
