## Copyright (c) 2020-2022 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements number cross-platform IO and OS procedures which do
## not use exceptions and using Result[T] for error handling.
##

when (NimMajor, NimMinor) < (1, 4):
  {.push raises: [Defect].}
else:
  {.push raises: [].}

import algorithm
import results
export results

when defined(windows):
  from strutils import replace, find

  const
    GENERIC_READ = 0x80000000'u32
    GENERIC_WRITE = 0x40000000'u32

    CREATE_NEW = 1'u32
    CREATE_ALWAYS = 2'u32
    OPEN_EXISTING = 3'u32
    OPEN_ALWAYS = 4'u32
    TRUNCATE_EXISTING = 5'u32

    FILE_FLAG_OVERLAPPED = 0x40000000'u32
    FILE_SHARE_READ = 0x00000001'u32
    FILE_SHARE_WRITE = 0x00000002'u32

    FILE_FLAG_NO_BUFFERING = 0x20000000'u32
    FILE_ATTRIBUTE_READONLY = 0x00000001'u32
    FILE_ATTRIBUTE_DIRECTORY = 0x00000010'u32

    INVALID_HANDLE_VALUE = cast[uint](-1)
    INVALID_FILE_SIZE = cast[uint32](-1)
    INVALID_FILE_ATTRIBUTES = cast[uint32](-1)
    MAX_PATH = 260

    ERROR_ALREADY_EXISTS = 183'u32
    ERROR_FILE_NOT_FOUND = 2'u32

    FILE_BEGIN = 0'u32
    FILE_CURRENT = 1'u32
    FILE_END = 2'u32

    DirSep* = '\\'
    AltSep* = '/'
    BothSeps* = {DirSep, AltSep}

    FileBasicInfoClass = 0'u32

  type
    IoErrorCode* = distinct uint32
    IoHandle* = distinct uint

    SECURITY_ATTRIBUTES {.final, pure.} = object
      nLength: uint32
      lpSecurityDescriptor: pointer
      bInheritHandle: int32

    FILETIME {.final, pure.} = object
      dwLowDateTime: uint32
      dwHighDateTime: uint32

    WIN32_FIND_DATAW {.final, pure.} = object
      dwFileAttributes: uint32
      ftCreationTime: FILETIME
      ftLastAccessTime: FILETIME
      ftLastWriteTime: FILETIME
      nFileSizeHigh: uint32
      nFileSizeLow: uint32
      dwReserved0: uint32
      dwReserved1: uint32
      cFileName: array[MAX_PATH, Utf16Char]
      cAlternateFileName: array[14, Utf16Char]

    BY_HANDLE_FILE_INFORMATION {.final, pure.} = object
      dwFileAttributes: uint32
      ftCreationTime: FILETIME
      ftLastAccessTime: FILETIME
      ftLastWriteTime: FILETIME
      dwVolumeSerialNumber: uint32
      nFileSizeHigh: uint32
      nFileSizeLow: uint32
      nNumberOfLinks: uint32
      nFileIndexHigh: uint32
      nFileIndexLow: uint32

    FILE_BASIC_INFO {.final, pure.} = object
      creationTime: uint64
      lastAccessTime: uint64
      lastWriteTime: uint64
      changeTime: uint64
      fileAttributes: uint32

    OVERLAPPED* {.pure, inheritable.} = object
      internal*: uint
      internalHigh*: uint
      offset*: uint32
      offsetHigh*: uint32
      hEvent*: IoHandle

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
  proc deleteFileW(pathName: WideCString): uint32 {.
       importc: "DeleteFileW", dynlib: "kernel32", stdcall.}
  proc closeHandle(hobj: uint): int32 {.
       importc: "CloseHandle", dynlib: "kernel32", stdcall, sideEffect.}
  proc writeFile(hFile: uint, lpBuffer: pointer,
                 nNumberOfBytesToWrite: uint32,
                 lpNumberOfBytesWritten: var uint32,
                 lpOverlapped: pointer): int32 {.
       importc: "WriteFile", dynlib: "kernel32", stdcall, sideEffect.}
  proc readFile(hFile: uint, lpBuffer: pointer,
                nNumberOfBytesToRead: uint32,
                lpNumberOfBytesRead: var uint32,
                lpOverlapped: pointer): int32 {.
       importc: "ReadFile", dynlib: "kernel32", stdcall, sideEffect.}
  proc getFileAttributes(path: WideCString): uint32 {.
       importc: "GetFileAttributesW", dynlib: "kernel32", stdcall, sideEffect.}
  proc setFileAttributes(path: WideCString, dwAttributes: uint32): uint32 {.
       importc: "SetFileAttributesW", dynlib: "kernel32", stdcall, sideEffect.}
  proc getCurrentDirectoryW(nBufferLength: uint32,
                            lpBuffer: WideCString): uint32 {.
       importc: "GetCurrentDirectoryW", dynlib: "kernel32", stdcall,
       sideEffect.}
  proc formatMessageW(dwFlags: uint32, lpSource: pointer,
                      dwMessageId, dwLanguageId: uint32,
                      lpBuffer: pointer, nSize: uint32,
                      arguments: pointer): uint32 {.
       importc: "FormatMessageW", stdcall, dynlib: "kernel32".}
  proc localFree(p: pointer): uint {.
       importc: "LocalFree", stdcall, dynlib: "kernel32", sideEffect.}
  proc getLongPathNameW(lpszShortPath: WideCString, lpszLongPath: WideCString,
                        cchBuffer: uint32): uint32 {.
       importc: "GetLongPathNameW", dynlib: "kernel32.dll", stdcall,
       sideEffect.}
  proc findFirstFileW(lpFileName: WideCString,
                      lpFindFileData: var WIN32_FIND_DATAW): uint {.
       importc: "FindFirstFileW", dynlib: "kernel32", stdcall, sideEffect.}
  proc findClose(hFindFile: uint): int32 {.
       importc: "FindClose", dynlib: "kernel32", stdcall, sideEffect.}
  proc getFileInformationByHandle(hFile: uint,
                                 info: var BY_HANDLE_FILE_INFORMATION): int32 {.
       importc: "GetFileInformationByHandle", dynlib: "kernel32", stdcall,
       sideEffect.}
  proc getFileInformationByHandleEx(hFile: uint, information: uint32,
                                    lpFileInformation: pointer,
                                    dwBufferSize: uint32): int32 {.
       importc: "GetFileInformationByHandleEx", dynlib: "kernel32", stdcall,
       sideEffect.}
  proc setFileInformationByHandle(hFile: uint, information: uint32,
                                  lpFileInformation: pointer,
                                  dwBufferSize: uint32): int32 {.
       importc: "SetFileInformationByHandle", dynlib: "kernel32", stdcall,
       sideEffect.}
  proc getFileSize(hFile: uint, lpFileSizeHigh: var uint32): uint32 {.
       importc: "GetFileSize", dynlib: "kernel32", stdcall, sideEffect.}
  proc setFilePointerEx(hFile: uint, liDistanceToMove: int64,
                        lpNewFilePointer: ptr int64,
                        dwMoveMethod: uint32): int32 {.
       importc: "SetFilePointerEx", dynlib: "kernel32", stdcall, sideEffect.}
  proc lockFileEx(hFile: uint, dwFlags, dwReserved: uint32,
                  nNumberOfBytesToLockLow, nNumberOfBytesToLockHigh: uint32,
                  lpOverlapped: pointer): uint32 {.
       importc: "LockFileEx", dynlib: "kernel32", stdcall, sideEffect.}
  proc unlockFileEx(hFile: uint, dwReserved: uint32,
                    nNumberOfBytesToLockLow, nNumberOfBytesToLockHigh: uint32,
                    lpOverlapped: pointer): uint32 {.
       importc: "UnlockFileEx", dynlib: "kernel32", stdcall, sideEffect.}

  const
    NO_ERROR = IoErrorCode(0)
    LOCKFILE_EXCLUSIVE_LOCK = 0x00000002'u32
    LOCKFILE_FAIL_IMMEDIATELY = 0x00000001'u32

  proc `==`*(a: IoErrorCode, b: uint32): bool {.inline.} =
    (uint32(a) == b)

elif defined(posix):
  import posix

  const
    DirSep* = '/'
    AltSep* = '/'
    BothSeps* = {'/'}

    LOCK_SH* = 0x01
    LOCK_EX* = 0x02
    LOCK_NB* = 0x04
    LOCK_UN* = 0x08

  type
    IoHandle* = distinct cint
    IoErrorCode* = distinct cint

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

  type
    FlockStruct* {.importc: "struct flock", final, pure,
                   header: "<fcntl.h>".} = object
      ltype* {.importc: "l_type".}: cshort
      lwhence* {.importc: "l_whence".}: cshort
      start* {.importc: "l_start".}: int
      length* {.importc: "l_len".}: int
      pid* {.importc: "l_pid".}: int32

  var errno {.importc, header: "<errno.h>".}: cint

  proc write(a1: cint, a2: pointer, a3: csize_t): int {.
       importc, header: "<unistd.h>", sideEffect.}
  proc read(a1: cint, a2: pointer, a3: csize_t): int {.
       importc, header: "<unistd.h>", sideEffect.}
  proc c_strerror(errnum: cint): cstring {.
       importc: "strerror", header: "<string.h>", sideEffect.}
  proc c_free(p: pointer) {.
       importc: "free", header: "<stdlib.h>", sideEffect.}
  proc getcwd(a1: cstring, a2: int): cstring {.
       importc, header: "<unistd.h>", sideEffect.}

  proc `==`*(a: IoErrorCode, b: cint): bool {.inline.} =
    (cint(a) == b)

type
  IoResult*[T] = Result[T, IoErrorCode]

  OpenFlags* {.pure.} = enum
    Read, Write, Create, Exclusive, Append, Truncate,
    Inherit, NonBlock, Direct, ShareRead, ShareWrite

  Permission* = enum
    UserRead, UserWrite, UserExec,
    GroupRead, GroupWrite, GroupExec,
    OtherRead, OtherWrite, OtherExec

  Permissions* = set[Permission]

  SeekPosition* = enum
    SeekBegin, SeekCurrent, SeekEnd

  AccessFlags* {.pure.} = enum
    Find, Read, Write, Execute

  LockType* {.pure.} = enum
    Shared, Exclusive

  IoLockHandle* = object
    handle*: IoHandle
    offset*: int64
    size*: int64

const
  NimErrorCode = 100_000
  UnsupportedFileSize* = IoErrorCode(NimErrorCode)
  UserErrorCode* = 1_000_000

proc `==`*(a, b: IoErrorCode): bool {.borrow.}
proc `$`*(a: IoErrorCode): string {.borrow.}

{.push stackTrace:off.}
proc ioLastError*(): IoErrorCode {.sideEffect.} =
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
    IoErrorCode(getLastError())
  else:
    IoErrorCode(errno)
{.pop.}

proc ioErrorMsg*(code: IoErrorCode): string =
  ## Converts an OS error code into a human readable string.
  if int(code) == 0:
    ""
  elif int(code) >= NimErrorCode:
    case code
    of UnsupportedFileSize:
      "(" & $code & ") " & "File size is unsupported"
    else:
      "(" & $code & ") " & "Unknown error"
  else:
    when defined(posix):
      $c_strerror(cint(code))
    elif defined(windows):
      var msgbuf: WideCString
      if formatMessageW(0x00000100'u32 or 0x00001000'u32 or 0x00000200'u32,
                        nil, uint32(code), 0, addr(msgbuf), 0, nil) != 0'u32:
        var res = $msgbuf
        if not(isNil(msgbuf)):
          discard localFree(cast[pointer](msgbuf))
        res
      else:
        ""

proc normPathEnd(path: var string, trailingSep: bool) =
  ## Ensures ``path`` has exactly 0 or 1 trailing `DirSep`, depending on
  ## ``trailingSep``, and taking care of edge cases: it preservers whether
  ## a path is absolute or relative, and makes sure trailing sep is `DirSep`,
  ## not `AltSep`. Trailing `/.` are compressed.
  var i = len(path)
  if i > 0:
    while i >= 1:
      if path[i - 1] in BothSeps:
        dec(i)
      elif path[i - 1] == '.' and (i >= 2) and (path[i - 2] in BothSeps):
        dec(i)
      else:
        break
    if trailingSep:
      path.setLen(i)
      path.add DirSep
    elif i > 0:
      path.setLen(i)
    else:
      path = $DirSep

when defined(windows):
  proc fixPath(path: string): string =
    ## If ``path`` is absolute path and length of ``path`` exceedes
    ## MAX_PATH number of characeters - ``path`` will be prefixed with ``\\?\``
    ## value which disable all string parsing and send the string that follows
    ## prefix straight to the file system.
    ##
    ## MAX_PATH limitation has different meaning for directory paths, because
    ## when creating directory 12 characters will be reserved for 8.3 filename,
    ## that's why we going to apply prefix for all paths which are bigger than
    ## MAX_PATH - 12.
    if len(path) < MAX_PATH - 12: return path
    if ((path[0] in {'a' .. 'z', 'A' .. 'Z'}) and path[1] == ':'):
      "\\\\?\\" & path
    else:
      path

proc splitDrive*(path: string): tuple[head: string, tail: string] =
  ## Split the pathname ``path`` into drive/UNC sharepoint and relative path
  ## specifiers.
  ##
  ## Returns a 2-tuple (head, tail); either part may be empty.
  ##
  ## If the path contained a drive letter, ``head`` will contain everything
  ## up to and including the colon. e.g. ``splitDrive("c:/dir")`` returns
  ## ("c:", "/dir").
  ##
  ## If the path contained a UNC path, the ``head`` will contain the host name
  ## and share up to but not including the fourth directory separator
  ## character. e.g. ``splitDrive("//host/computer/dir")`` returns
  ## ("//host/computer", "/dir")
  ##
  ## Note, paths cannot contain both a drive letter and a UNC path.
  when defined(posix):
    # On Posix, drive is always empty
    ("", path)
  elif defined(windows):
    if len(path) < 2:
      return ("", path)
    let normp = path.replace('/', '\\')
    if (len(path) > 2) and
       normp[0] == '\\' and normp[1] == '\\' and normp[2] != '\\':
      let index = normp.find('\\', 2)
      if index == -1:
        return ("", path)
      let index2 = normp.find('\\', index + 1)
      if index2 == index + 1:
        return ("", path)
      return (path[0 ..< index2], path[index2 .. ^1])
    if normp[1] == ':':
      return (path[0 .. 1], path[2 .. ^1])
    return ("", path)

proc splitPath*(path: string): tuple[head: string, tail: string] =
  ## Split the pathname ``path`` into a pair, (head, tail) where tail is the
  ## last pathname component and head is everything leading up to that.
  ##
  ## * The tail part will never contain a slash.
  ## * If path ends in a slash, tail will be empty.
  ## * If there is no slash in path, head will be empty.
  ## * If path is empty, both head and tail are empty.
  ## * Trailing slashes are stripped from head unless it is the root
  ##   (one or more slashes only)
  if len(path) == 0:
    ("", "")
  else:
    let (drive, p) = splitDrive(path)
    let pathlen = len(p)
    var i = pathlen
    while (i != 0) and (p[i - 1]) notin BothSeps:
      dec(i)
    let head = p[0 ..< i]
    let tail = p[i ..< pathlen]
    var headStrip = head
    i = len(headStrip)
    while (i != 0) and (headStrip[i - 1]) in BothSeps:
      dec(i)
    headStrip.setLen(i)
    if len(headStrip) == 0:
      (drive & head, tail)
    else:
      (drive & headStrip, tail)

proc basename*(path: string): string =
  ## Return the base name of pathname ``path``.
  ##
  ## Note that the result of this procedure is different from the Unix basename
  ## program; where basename for "/foo/bar/" returns "bar", the basename()
  ## procedure returns an empty string ("").
  splitPath(path)[1]

proc dirname*(path: string): string =
  ## Return the directory name of pathname ``path``.
  splitPath(path)[0]

when defined(windows):
  proc toLongPath*(path: string): IoResult[string] =
    let shortPath = newWideCString(path)
    var buffer = newSeq[Utf16Char](len(path) * 2 + 1)
    while true:
      let res = getLongPathNameW(shortPath, cast[WideCString](addr buffer[0]),
                                 uint32(len(buffer)))
      if res == 0:
        return err(ioLastError())
      else:
        if res <= uint32(len(buffer)):
          return ok($cast[WideCString](addr buffer[0]))
        else:
          buffer.setLen(res)
          continue

proc getCurrentDir*(): IoResult[string] =
  ## Returns string containing an absolute pathname that is the current working
  ## directory of the calling process.
  when defined(posix):
    while true:
      let res = getcwd(nil, 0)
      if isNil(res):
        let errCode = ioLastError()
        if errCode == EINTR:
          continue
        else:
          return err(errCode)
      else:
        var buffer = $res
        c_free(res)
        return ok(buffer)
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

proc setUmask*(mask: int): int {.inline.} =
  ## Procedure shall set the file mode creation mask of the process to ``mask``
  ## and return the previous value of the ``mask``.
  ##
  ## Note: On Windows this is empty procedure which always returns ``0``.
  when defined(windows):
    0
  else:
    int(posix.umask(Mode(mask)))

proc rawCreateDir(dir: string, mode: int = 0o755,
                  secDescriptor: pointer = nil): IoResult[bool] =
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
      let existFlags = [EEXIST, ENOSYS]
    elif defined(haiku):
      let existFlags = [EEXIST, EROFS]
    else:
      let existFlags = [EEXIST]
    while true:
      let omask = setUmask(0)
      let res = posix.mkdir(cstring(dir), Mode(mode))
      discard setUmask(omask)
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
      lpSecurityDescriptor: secDescriptor,
      bInheritHandle: 0
    )
    let res = createDirectoryW(newWideCString(fixPath(dir)), sa)
    if res != 0'i32:
      ok(true)
    else:
      let errCode = ioLastError()
      if errCode == ERROR_ALREADY_EXISTS:
        ok(false)
      else:
        err(errCode)

proc removeDir*(dir: string): IoResult[void] =
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
    let res = removeDirectoryW(newWideCString(fixPath(dir)))
    if res != 0'i32:
      ok()
    else:
      err(ioLastError())

proc removeFile*(path: string): IoResult[void] =
  ## Deletes a file ``path``.
  ##
  ## Procedure will not fail, if file do not exist.
  when defined(posix):
    if posix.unlink(path) != 0'i32:
      let errCode = ioLastError()
      if errCode == ENOENT:
        ok()
      else:
        err(errCode)
    else:
      ok()
  elif defined(windows):
    if deleteFileW(newWideCString(fixPath(path))) == 0:
      let errCode = ioLastError()
      if errCode == ERROR_FILE_NOT_FOUND:
        ok()
      else:
        err(errCode)
    else:
      ok()

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
    let res = getFileAttributes(newWideCString(fixPath(path)))
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
    let res = getFileAttributes(newWideCString(fixPath(path)))
    if res == INVALID_FILE_ATTRIBUTES:
      false
    else:
      (res and FILE_ATTRIBUTE_DIRECTORY) == FILE_ATTRIBUTE_DIRECTORY

proc getPathItems(path: string, reverse: bool): seq[string] =
  var paths: seq[string]
  let root = $DirSep

  when defined(windows):
    let (drive, dpath) = splitDrive(path)
    var curpath = dpath
  else:
    var curpath = path

  normPathEnd(curpath, trailingSep = false)
  while true:
    let curbase = basename(curpath)
    let curdir = dirname(curpath)
    curpath = curdir
    if len(curbase) > 0:
      when defined(posix):
        if len(curdir) > 0 and curdir != root:
          paths.add(curdir & DirSep & curbase)
        else:
          paths.add(curdir & curbase)
      elif defined(windows):
        if len(curdir) > 0 and curdir != root:
          paths.add(drive & curdir & DirSep & curbase)
        else:
          paths.add(drive & curdir & curbase)
    else:
      break
  if reverse:
    paths.reverse()
  paths

proc createPath*(path: string, createMode: int = 0o755,
                 secDescriptor: pointer = nil): IoResult[void] =
  ## Creates the full path ``path`` with mode ``createMode``.
  ##
  ## Path may contain several subfolders that do not exist yet.
  ## The full path is created. If this fails, error will be returned.
  ##
  ## It does **not** fail if the folder already exists because for
  ## most usages this does not indicate an error.
  let paths = getPathItems(path, true)
  for item in paths:
    let res = rawCreateDir(item, createMode, secDescriptor)
    if res.isErr():
      return err(res.error)
  ok()

proc toPermissions*(mask: int): Permissions =
  ## Converts permissions mask's integer to set of ``Permission``.
  var res: Permissions
  when defined(posix):
    if (mask and S_IRUSR) != 0: res.incl(UserRead)
    if (mask and S_IWUSR) != 0: res.incl(UserWrite)
    if (mask and S_IXUSR) != 0: res.incl(UserExec)
    if (mask and S_IRGRP) != 0: res.incl(GroupRead)
    if (mask and S_IWGRP) != 0: res.incl(GroupWrite)
    if (mask and S_IXGRP) != 0: res.incl(GroupExec)
    if (mask and S_IROTH) != 0: res.incl(OtherRead)
    if (mask and S_IWOTH) != 0: res.incl(OtherWrite)
    if (mask and S_IXOTH) != 0: res.incl(OtherExec)
    res
  elif defined(windows):
    if (mask and 0o400) != 0: res.incl(UserRead)
    if (mask and 0o200) != 0: res.incl(UserWrite)
    if (mask and 0o100) != 0: res.incl(UserExec)
    if (mask and 0o40) != 0: res.incl(GroupRead)
    if (mask and 0o20) != 0: res.incl(GroupWrite)
    if (mask and 0o10) != 0: res.incl(GroupExec)
    if (mask and 0o4) != 0: res.incl(OtherRead)
    if (mask and 0o2) != 0: res.incl(OtherWrite)
    if (mask and 0o1) != 0: res.incl(OtherExec)
    res

proc toInt*(mask: Permissions): int =
  ## Converts set of ``Permission`` to permissions mask's integer.
  var rnum = 0
  when defined(windows):
    if UserRead in mask:
      rnum = rnum or 0o400
    if UserWrite in mask:
      rnum = rnum or 0o200
    if UserExec in mask:
      rnum = rnum or 0o100
    if GroupRead in mask:
      rnum = rnum or 0o40
    if GroupWrite in mask:
      rnum = rnum or 0o20
    if GroupExec in mask:
      rnum = rnum or 0o10
    if OtherRead in mask:
      rnum = rnum or 0o4
    if OtherWrite in mask:
      rnum = rnum or 0o2
    if OtherExec in mask:
      rnum = rnum or 0o1
    rnum
  elif defined(posix):
    if UserRead in mask:
      rnum = rnum or S_IRUSR
    if UserWrite in mask:
      rnum = rnum or S_IWUSR
    if UserExec in mask:
      rnum = rnum or S_IXUSR
    if GroupRead in mask:
      rnum = rnum or S_IRGRP
    if GroupWrite in mask:
      rnum = rnum or S_IWGRP
    if GroupExec in mask:
      rnum = rnum or S_IXGRP
    if OtherRead in mask:
      rnum = rnum or S_IROTH
    if OtherWrite in mask:
      rnum = rnum or S_IWOTH
    if OtherExec in mask:
      rnum = rnum or S_IXOTH
    rnum
  else:
    0o777

proc getPermissions*(pathName: string): IoResult[int] =
  ## Retreive permissions of file/folder ``pathName`` and return it as integer.
  when defined(posix):
    var a: posix.Stat
    let res = posix.stat(pathName, a)
    if res == 0:
      ok(int(a.st_mode) and 0o777)
    else:
      err(ioLastError())
  elif defined(windows):
    let res = getFileAttributes(newWideCString(fixPath(pathName)))
    if res == INVALID_FILE_ATTRIBUTES:
      err(ioLastError())
    else:
      if (res and FILE_ATTRIBUTE_READONLY) == FILE_ATTRIBUTE_READONLY:
        ok(0o555)
      else:
        ok(0o777)
  else:
    ok(0o777)

proc getPermissions*(handle: IoHandle): IoResult[int] =
  ## Retrieve permissions for file descriptor ``handle`` and return it as
  ## integer.
  when defined(posix):
    var statbuf: posix.Stat
    let res = posix.fstat(cint(handle), statbuf)
    if res == 0:
      ok(int(statbuf.st_mode) and 0o777)
    else:
      err(ioLastError())
  elif defined(windows):
    var info: BY_HANDLE_FILE_INFORMATION
    let res = getFileInformationByHandle(uint(handle), info)
    if res != 0:
      let attr = info.dwFileAttributes
      if (attr and FILE_ATTRIBUTE_READONLY) == FILE_ATTRIBUTE_READONLY:
        ok(0o555)
      else:
        ok(0o777)
    else:
      err(ioLastError())
  else:
    ok(0o777)

proc getPermissionsSet*(pathName: string): IoResult[Permissions] =
  ## Retreive permissions of file/folder ``pathName`` and return set of
  ## ``Permission`.
  let mask = ? getPermissions(pathName)
  when defined(windows) or defined(posix):
    ok(mask.toPermissions())
  else:
    ok({UserRead .. OtherExec})

proc getPermissionsSet*(handle: IoHandle): IoResult[Permissions] =
  let mask = ? getPermissions(handle)
  when defined(windows) or defined(posix):
    ok(mask.toPermissions())
  else:
    ok({UserRead .. OtherExec})

proc setPermissions*(pathName: string, mask: int): IoResult[void] =
  ## Set permissions for file/folder ``pathame``.
  when defined(windows):
    let gres = getFileAttributes(newWideCString(fixPath(pathName)))
    if gres == INVALID_FILE_ATTRIBUTES:
      err(ioLastError())
    else:
      let nmask =
        if (mask and 0o222) == 0:
          gres or uint32(FILE_ATTRIBUTE_READONLY)
        else:
          gres and not(FILE_ATTRIBUTE_READONLY)
      let sres = setFileAttributes(newWideCString(fixPath(pathName)),
                                   nmask)
      if sres == 0:
        err(ioLastError())
      else:
        ok()
  elif defined(posix):
    while true:
      let omask = setUmask(0)
      let res = posix.chmod(pathName, Mode(mask))
      discard setUmask(omask)
      if res == 0:
        return ok()
      else:
        let errCode = ioLastError()
        if errCode == EINTR:
          continue
        else:
          return err(errCode)

proc setPermissions*(handle: IoHandle, mask: int): IoResult[void] =
  ## Set permissions for handle ``handle``.
  when defined(posix):
    while true:
      let omask = setUmask(0)
      let res = posix.fchmod(cint(handle), Mode(mask))
      discard setUmask(omask)
      if res == 0:
        return ok()
      else:
        let errCode = ioLastError()
        if errCode == EINTR:
          continue
        else:
          return err(errCode)
  elif defined(windows):
    var info: FILE_BASIC_INFO
    let infoSize = uint32(sizeof(FILE_BASIC_INFO))

    let gres = getFileInformationByHandleEx(uint(handle),
                                            FileBasicInfoClass,
                                            cast[pointer](addr info), infoSize)
    if gres == 0:
      err(ioLastError())
    else:
      info.fileAttributes =
        if (mask and 0o222) == 0:
          info.fileAttributes or uint32(FILE_ATTRIBUTE_READONLY)
        else:
          info.fileAttributes and not(FILE_ATTRIBUTE_READONLY)
      let sres = setFileInformationByHandle(uint(handle),
                                            FileBasicInfoClass,
                                            cast[pointer](addr info), infoSize)
      if sres == 0:
        err(ioLastError())
      else:
        ok()

proc setPermissions*(pathName: string, mask: Permissions): IoResult[void] =
  ## Set permissions for file/folder ``pathame`` using mask ``mask``.
  setPermissions(pathName, mask.toInt())

proc setPermissions*(handle: IoHandle, mask: Permissions): IoResult[void] =
  ## Set permissions for file descriptor ``handle`` using mask ``mask``.
  setPermissions(handle, mask.toInt())

proc fileAccessible*(pathName: string, mask: set[AccessFlags]): bool =
  ## Checks the file ``pathName`` for accessibility according to the bit
  ## pattern contained in ``mask``.
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
    let res = getFileAttributes(newWideCString(fixPath(pathName)))
    if res == INVALID_FILE_ATTRIBUTES:
      return false
    if AccessFlags.Write in mask:
      if (res and FILE_ATTRIBUTE_READONLY) == FILE_ATTRIBUTE_READONLY:
        return false
      else:
        return true
    return true

proc toString*(mask: Permissions): string =
  ## Return mask representation as human-readable string in format
  ## "0xxx (---------)" where `xxx` is numeric representation of permissions.
  var rnum = 0
  var rstr = "0000 (---------)"
  if UserRead in mask:
    rstr[6] = 'r'
    rnum = rnum or 0o400
  if UserWrite in mask:
    rstr[7] = 'w'
    rnum = rnum or 0o200
  if UserExec in mask:
    rstr[8] = 'x'
    rnum = rnum or 0o100
  if GroupRead in mask:
    rstr[9] = 'r'
    rnum = rnum or 0o40
  if GroupWrite in mask:
    rstr[10] = 'w'
    rnum = rnum or 0o20
  if GroupExec in mask:
    rstr[11] = 'x'
    rnum = rnum or 0o10
  if OtherRead in mask:
    rstr[12] = 'r'
    rnum = rnum or 0o4
  if OtherWrite in mask:
    rstr[13] = 'w'
    rnum = rnum or 0o2
  if OtherExec in mask:
    rstr[14] = 'x'
    rnum = rnum or 0o1
  if (rnum and 0o700) != 0:
    rstr[1] = ($((rnum shr 6) and 0x07))[0]
  if (rnum and 0o70) != 0:
    rstr[2] = ($((rnum shr 3) and 0x07))[0]
  if (rnum and 0o7) != 0:
    rstr[3] = ($(rnum and 0x07))[0]
  rstr

proc checkPermissions*(pathName: string, mask: int): bool =
  ## Checks if the file ``pathName`` permissions is equal to ``mask``.
  when defined(windows):
    true
  elif defined(posix):
    var statbuf: posix.Stat
    let res = posix.stat(pathName, statbuf)
    if res == 0:
      (int(statbuf.st_mode) and 0o777) == mask
    else:
      false
  else:
    true

proc openFile*(pathName: string, flags: set[OpenFlags],
               createMode: int = 0o644,
               secDescriptor: pointer = nil): IoResult[IoHandle] =
  when defined(posix):
    var cflags: cint

    if (OpenFlags.Read in flags) and (OpenFlags.Write in flags):
      cflags = cflags or posix.O_RDWR
    else:
      if OpenFlags.Write in flags:
        cflags = cflags or posix.O_WRONLY
      else:
        cflags = cflags or posix.O_RDONLY

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
    if OpenFlags.Inherit notin flags:
      cflags = cflags or O_CLOEXEC
    if OpenFlags.NonBlock in flags:
      cflags = cflags or posix.O_NONBLOCK

    while true:
      let omask = setUmask(0)
      let ores = posix.open(cstring(pathName), cflags, Mode(createMode))
      discard setUmask(omask)
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
                return ok(IoHandle(ores))
          else:
            return ok(IoHandle(ores))
        else:
          return ok(IoHandle(ores))
  elif defined(windows):
    var
      dwAccess: uint32
      dwShareMode: uint32
      dwCreation: uint32
      dwFlags: uint32

    var sa = SECURITY_ATTRIBUTES(
      nLength: uint32(sizeof(SECURITY_ATTRIBUTES)),
      lpSecurityDescriptor: secDescriptor,
      bInheritHandle: 0
    )

    if (OpenFlags.Write in flags) and (OpenFlags.Read in flags):
      dwAccess = dwAccess or (GENERIC_READ or GENERIC_WRITE)
    else:
      if OpenFlags.Write in flags:
        dwAccess = dwAccess or GENERIC_WRITE
      else:
        dwAccess = dwAccess or GENERIC_READ

    if {OpenFlags.Create, OpenFlags.Exclusive} <= flags:
      dwCreation = dwCreation or CREATE_NEW
    elif OpenFlags.Truncate in flags:
      if OpenFlags.Create in flags:
        dwCreation = dwCreation or CREATE_ALWAYS
      elif OpenFlags.Read notin flags:
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

    if OpenFlags.ShareRead in flags:
      dwShareMode = dwShareMode or FILE_SHARE_READ
    if OpenFlags.ShareWrite in flags:
      dwShareMode = dwShareMode or FILE_SHARE_WRITE

    if OpenFlags.NonBlock in flags:
      dwFlags = dwFlags or FILE_FLAG_OVERLAPPED
    if OpenFlags.Direct in flags:
      dwFlags = dwFlags or FILE_FLAG_NO_BUFFERING
    if OpenFlags.Inherit in flags:
      sa.bInheritHandle = 1

    let res = createFileW(newWideCString(fixPath(pathName)), dwAccess,
                          dwShareMode, sa, dwCreation, dwFlags, 0'u32)
    if res == INVALID_HANDLE_VALUE:
      err(ioLastError())
    else:
      ok(IoHandle(res))

proc closeFile*(handle: IoHandle): IoResult[void] =
  ## Closes file descriptor handle ``handle``.
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

proc writeFile*(handle: IoHandle,
                data: openArray[byte]): IoResult[uint] =
  ## Write ``data`` bytes to file descriptor ``handle``.
  ##
  ## Returns number of bytes written.
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

proc writeFile*(handle: IoHandle,
                data: openArray[char]): IoResult[uint] {.inline.} =
  ## Write ``data`` characters to file descriptor ``handle``.
  ##
  ## Returns number of characters written.
  writeFile(handle, data.toOpenArrayByte(0, len(data) - 1))

proc readFile*(handle: IoHandle,
               data: var openArray[byte]): IoResult[uint] =
  ## Reads ``len(data)`` bytes from file descriptor ``handle`` and store this
  ## bytes to ``data``.
  ##
  ## Returns number of bytes read from file descriptor.
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

proc readFile*(handle: IoHandle,
               data: var openArray[char]): IoResult[uint] {.inline.} =
  ## Reads ``len(data)`` characters from file descriptor ``handle`` and store
  ## this characters to ``data``.
  ##
  ## Returns number of bytes characters read from file descriptor.
  readFile(handle, data.toOpenArrayByte(0, len(data) - 1))

proc writeFile*(pathName: string, data: openArray[byte],
                createMode: int = 0o644,
                secDescriptor: pointer = nil): IoResult[void] =
  ## Opens a file named ``pathName`` for writing. Then writes the
  ## content ``data`` completely to the file and closes the file afterwards.
  ##
  ## If file is not exists it will be created with permissions mask
  ## ``createMode`` (default value is 0o644).
  ##
  ## If file is already exists, it will be truncated to 0 size first,
  ## after it will try to set permissions to ``createMode`` and only
  ## after success it will write data ``data`` to file.
  let flags = {OpenFlags.Write, OpenFlags.Truncate, OpenFlags.Create}
  let handle = ? openFile(pathName, flags, createMode, secDescriptor)
  ? setPermissions(handle, createMode)
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

when defined(windows):
  template makeInt64(a, b: uint32): int64 =
    (int64(a and 0x7FFF_FFFF'u32) shl 32) or int64(b and 0xFFFF_FFFF'u32)
  template makeUint32(a: uint64): tuple[lowPart: uint32, highPart: uint32] =
    (uint32(a and 0xFFFF_FFFF'u64), uint32((a shr 32) and 0xFFFF_FFFF'u64))

proc writeFile*(pathName: string, data: openArray[char],
                createMode: int = 0o644,
                secDescriptor: pointer = nil): IoResult[void] {.inline.} =
  ## Opens a file named ``pathName`` for writing. Then writes the
  ## content ``data`` completely to the file and closes the file afterwards.
  ##
  ## If file is not exists it will be created with permissions mask
  ## ``createMode`` (default value is 0o644).
  writeFile(pathName, data.toOpenArrayByte(0, len(data) - 1), createMode,
            secDescriptor)

proc getFileSize*(pathName: string): IoResult[int64] =
  ## Returns size in bytes of the specified file ``pathName``.
  when defined(posix):
    var a: posix.Stat
    let res = posix.stat(pathName, a)
    if res == -1:
      err(ioLastError())
    else:
      ok(int64(a.st_size))
  elif defined(windows):
    var wfd: WIN32_FIND_DATAW
    let res = findFirstFileW(newWideCString(fixPath(pathName)), wfd)
    if res == INVALID_HANDLE_VALUE:
      err(ioLastError())
    else:
      if findClose(res) == 0:
        err(ioLastError())
      else:
        ok(makeInt64(wfd.nFileSizeHigh, wfd.nFileSizeLow))

proc getFileSize*(handle: IoHandle): IoResult[int64] =
  ## Returns size in bytes of file specified by file descriptor ``handle``.
  when defined(posix):
    var statbuf: posix.Stat
    let res = posix.fstat(cint(handle), statbuf)
    if res == 0:
      ok(int64(statbuf.st_size))
    else:
      err(ioLastError())
  elif defined(windows):
    var highPart: uint32
    let res = getFileSize(uint(handle), highPart)
    if res == INVALID_FILE_SIZE:
      let errCode = ioLastError()
      if errCode == NO_ERROR:
        ok(makeInt64(highPart, res))
      else:
        err(errCode)
    else:
      ok(makeInt64(highPart, res))

proc getFilePos*(handle: IoHandle): IoResult[int64] =
  ## Returns current file offset for the open file associated with the file
  ## descriptor ``handle``.
  when defined(windows):
    let whence = FILE_CURRENT
    var pos: int64
    let res = setFilePointerEx(uint(handle), 0'i64, addr pos, whence)
    if res == 0:
      err(ioLastError())
    else:
      ok(pos)
  elif defined(posix):
    let res = int64(posix.lseek(cint(handle), Off(0), posix.SEEK_CUR))
    if res == -1'i64:
      err(ioLastError())
    else:
      ok(int64(res))

proc setFilePos*(handle: IoHandle, offset: int64,
                 whence: SeekPosition): IoResult[void] =
  ## Procedure shall set the file offset for the open file associated with the
  ## file descriptor ``handle``, as follows:
  ##   * If whence is ``SeekPosition.SeekBegin``, the file offset shall be set
  ##     to ``offset`` bytes.
  ##   * If whence is ``SeekPosition.SeekCur``, the file offset shall be set to
  ##     its current location plus ``offset``.
  ##   * If whence is ``SeekPosition.SeekEnd``, the file offset shall be set to
  ##     the size of the file plus ``offset``.
  when defined(windows):
    let pos =
      case whence
      of SeekBegin:
        FILE_BEGIN
      of SeekCurrent:
        FILE_CURRENT
      of SeekEnd:
        FILE_END
    let res = setFilePointerEx(uint(handle), offset, nil, pos)
    if res == 0:
      err(ioLastError())
    else:
      ok()
  else:
    let pos =
      case whence
      of SeekBegin:
        posix.SEEK_SET
      of SeekCurrent:
        posix.SEEK_CUR
      of SeekEnd:
        posix.SEEK_END
    let res = int64(posix.lseek(cint(handle), Off(offset), pos))
    if res == -1'i64:
      err(ioLastError())
    else:
      ok()

proc checkFileSize*(value: int64): IoResult[void] =
  ## Checks if ``value`` fits into supported by Nim string/sequence indexing
  ## mechanism.
  ##
  ##   * For 32-bit systems the maximum value is 0x7FFF_FFFF'i64.
  ##   * For 64-bit systems the maximum value is 0x7FFF_FFFF_FFFF_FFFF'i64.
  when sizeof(int) == 4:
    if value > 0x7FFF_FFFF'i64:
      err(UnsupportedFileSize)
    else:
      ok()
  elif sizeof(int) == 8:
    ok()

proc readFile*[T: byte|char](pathName: string,
                             data: var openArray[T]): IoResult[uint] =
  ## Try to read all data from file ``pathName`` and store it to ``data``.
  ## If size of ``data`` is not enough to store all data, only part of data
  ## will be stored.
  ##
  ## Returns number of bytes read.
  let flags = {OpenFlags.Read}
  let handle = ? openFile(pathName, flags)
  let res = readFile(handle, data)
  if res.isErr():
    # Do not care about `closeFile(handle)` error because we already in
    # error handler.
    discard closeFile(handle)
    err(res.error)
  else:
    ? closeFile(handle)
    ok(res.get())

proc readFile*[T: seq[byte]|string](pathName: string,
                                    data: var T): IoResult[void] =
  ## Read all data from file ``pathName`` and store it to ``data``.
  let fileSize = ? getFileSize(pathName)
  ? checkFileSize(fileSize)
  data.setLen(fileSize)
  let res {.used.} = ? readFile(pathName, data.toOpenArray(0, len(data) - 1))
  ok()

proc readAllBytes*(pathName: string): IoResult[seq[byte]] =
  ## Read all bytes/characters from file and return it as sequence of bytes.
  var data: seq[byte]
  ? readFile(pathName, data)
  ok(data)

proc readAllChars*(pathName: string): IoResult[string] =
  ## Read all bytes/characters from file and return it as string.
  var data: string
  ? readFile(pathName, data)
  ok(data)

proc readAllFile*(pathName: string): IoResult[seq[byte]] =
  ## Alias for ``readAllBytes()``.
  readAllBytes(pathName)

proc lockFile*(handle: IoHandle, kind: LockType, offset,
               size: int64): IoResult[void] =
  ## Apply shared or exclusive file segment lock for file handle ``handle`` and
  ## range specified by ``offset`` and ``size`` parameters.
  ##
  ## ``kind`` - type of lock (shared or exclusive). Please note that only
  ## exclusive locks have cross-platform compatible behavior. Hovewer, exclusive
  ## locks require ``handle`` to be opened for writing.
  ##
  ## ``offset`` - starting byte offset in the file where the lock should
  ## begin. ``offset`` should be always bigger or equal to ``0``.
  ##
  ## ``size`` - length of the byte range to be locked. ``size`` should be always
  ## bigger or equal to ``0``.
  ##
  ## If ``offset`` and ``size`` are both equal to ``0`` the entire file is locked.
  doAssert(offset >= 0)
  doAssert(size >= 0)
  when defined(posix):
    let ltype =
      case kind
      of LockType.Shared:
        cshort(posix.F_RDLCK)
      of LockType.Exclusive:
        cshort(posix.F_WRLCK)
    var flockObj =
      when sizeof(int) == 8:
        # There is no need to perform overflow check, so we just cast.
        FlockStruct(ltype: ltype, lwhence: cshort(posix.SEEK_SET),
                    start: cast[int](offset), length: cast[int](size))
      else:
        # Currently we do not support `__USE_FILE_OFFSET64` or
        # `__USE_LARGEFILE64` because its Linux specific #defines, and is not
        # present on BSD systems. Therefore, on 32bit systems we do not support
        # range locks which exceed `int32` value size.
        if offset > int64(high(int)):
          return err(IoErrorCode(EFBIG))
        if size > int64(high(int)):
          return err(IoErrorCode(EFBIG))
        # We already made overflow check, so we just cast.
        FlockStruct(ltype: ltype, lwhence: cshort(posix.SEEK_SET),
                    start: cast[int](offset), length: cast[int](size))
    while true:
      let res = posix.fcntl(cint(handle), posix.F_SETLK, addr flockObj)
      if res == -1:
        let errCode = ioLastError()
        if errCode == EINTR:
          continue
        else:
          return err(errCode)
      else:
        return ok()
  elif defined(windows):
    let (lowOffsetPart, highOffsetPart, lowSizePart, highSizePart) =
      if offset == 0'i64 and size == 0'i64:
        # We try to keep cross-platform behavior on Windows. And we can do it
        # because: Locking a region that goes beyond the current end-of-file
        # position is not an error.
        (0'u32, 0'u32, 0xFFFF_FFFF'u32, 0xFFFF_FFFF'u32)
      else:
        let offsetTuple = makeUint32(uint64(offset))
        let sizeTuple = makeUint32(uint64(size))
        (offsetTuple[0], offsetTuple[1], sizeTuple[0], sizeTuple[1])
    var ovl = OVERLAPPED(offset: lowOffsetPart, offsetHigh: highOffsetPart)
    let
      flags =
        case kind
        of LockType.Shared:
          LOCKFILE_FAIL_IMMEDIATELY
        of LockType.Exclusive:
          LOCKFILE_FAIL_IMMEDIATELY or LOCKFILE_EXCLUSIVE_LOCK
      res = lockFileEx(uint(handle), flags, 0'u32, lowSizePart,
                       highSizePart, addr ovl)
    if res == 0:
      err(ioLastError())
    else:
      ok()

proc unlockFile*(handle: IoHandle, offset, size: int64): IoResult[void] =
  ## Clear shared or exclusive file segment lock for file handle ``handle`` and
  ## range specified by ``offset`` and ``size`` parameters.
  ##
  ## ``offset`` - starting byte offset in the file where the lock placed.
  ## ``offset`` should be always bigger or equal to ``0``.
  ##
  ## ``size`` - length of the byte range to be unlocked. ``size`` should be
  ## always bigger or equal to ``0``.
  doAssert(offset >= 0)
  doAssert(size >= 0)
  when defined(posix):
    let ltype = cshort(posix.F_UNLCK)
    var flockObj =
      when sizeof(int) == 8:
        # There is no need to perform overflow check, so we just cast.
        FlockStruct(ltype: ltype, lwhence: cshort(posix.SEEK_SET),
                    start: cast[int](offset), length: cast[int](size))
      else:
        # Currently we do not support `__USE_FILE_OFFSET64` because its
        # Linux specific #define, and it not present in BSD systems. So
        # on 32bit systems we do not support range locks which exceed `int32`
        # value size.
        if offset > int64(high(int)):
          return err(IoErrorCode(EFBIG))
        if size > int64(high(int)):
          return err(IoErrorCode(EFBIG))
        # We already made overflow check, so we just cast.
        FlockStruct(ltype: ltype, lwhence: cshort(posix.SEEK_SET),
                    start: cast[int](offset), length: cast[int](size))
    while true:
      let res = posix.fcntl(cint(handle), F_SETLK, addr flockObj)
      if res == -1:
        let errCode = ioLastError()
        if errCode == EINTR:
          continue
        else:
          return err(errCode)
      else:
        return ok()
  elif defined(windows):
    let (lowOffsetPart, highOffsetPart, lowSizePart, highSizePart) =
      if offset == 0'i64 and size == 0'i64:
        # We try to keep cross-platform behavior on Windows. And we can do it
        # because: Locking a region that goes beyond the current end-of-file
        # position is not an error.
        (0'u32, 0'u32, 0xFFFF_FFFF'u32, 0xFFFF_FFFF'u32)
      else:
        let offsetTuple = makeUint32(uint64(offset))
        let sizeTuple = makeUint32(uint64(size))
        (offsetTuple[0], offsetTuple[1], sizeTuple[0], sizeTuple[1])
    var ovl = OVERLAPPED(offset: lowOffsetPart, offsetHigh: highOffsetPart)
    let res = unlockFileEx(uint(handle), 0'u32, lowSizePart,
                           highSizePart, addr ovl)
    if res == 0:
      err(ioLastError())
    else:
      ok()

proc lockFile*(handle: IoHandle, kind: LockType): IoResult[IoLockHandle] =
  ## Apply exclusive or shared lock to whole file specified by file handle
  ## ``handle``.
  ##
  ## ``kind`` - type of lock (shared or exclusive). Please note that only
  ## exclusive locks have cross-platform compatible behavior. Hovewer, exclusive
  ## locks require ``handle`` to be opened for writing.
  ##
  ## On success returns ``IoLockHandle`` object which could be used for unlock.
  ? lockFile(handle, kind, 0'i64, 0'i64)
  ok(IoLockHandle(handle: handle, offset: 0'i64, size: 0'i64))

proc unlockFile*(lock: IoLockHandle): IoResult[void] =
  ## Clear shared or exclusive lock ``lock``.
  let res = unlockFile(lock.handle, lock.offset, lock.size)
  if res.isErr():
    err(res.error())
  else:
    ok()
