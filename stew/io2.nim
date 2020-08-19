## Copyright (c) 2020 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements number cross-platform IO and OS procedures which do
## not use exceptions and using Result[T] for error handling.
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
    FILE_FLAG_NO_BUFFERING = 0x20000000'u32
    FILE_SHARE_READ = 1'u32
    FILE_ATTRIBUTE_READONLY = 0x00000001'u32
    FILE_ATTRIBUTE_DIRECTORY = 0x00000010'u32

    INVALID_HANDLE_VALUE = cast[uint](-1)
    INVALID_FILE_ATTRIBUTES = cast[uint32](-1)
    MAX_PATH = 260

    ERROR_ALREADY_EXISTS = 183'u32
    ERROR_FILE_NOT_FOUND = 2'u32
    # ERROR_PATH_NOT_FOUND = 3'u32
    # ERROR_INSUFFICIENT_BUFFER = 122'u32

    DirSep* = '\\'
    AltSep* = '/'
    BothSeps* = {DirSep, AltSep}

  type
    IoErrorCode* = distinct uint32
    IoHandle* = distinct uint

    SECURITY_ATTRIBUTES {.final, pure.} = object
      nLength: uint32
      lpSecurityDescriptor: pointer
      bInheritHandle: int32

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
       importc: "LocalFree", stdcall, dynlib: "kernel32".}
  # proc getTempPathW(nBufferLength: uint32, lpBuffer: WideCString): uint32 {.
  #      importc: "GetTempPathW", dynlib: "kernel32", stdcall.}
  # proc getUserProfileDirectoryW(hToken: uint, lpProfileDir: WideCString,
  #                               lpcchSize: var uint32): uint32 {.
  #      importc: "GetUserProfileDirectoryW", dynlib: "userenv.dll", stdcall.}
  proc getLongPathNameW(lpszShortPath: WideCString, lpszLongPath: WideCString,
                        cchBuffer: uint32): uint32 {.
       importc: "GetLongPathNameW", dynlib: "kernel32.dll", stdcall.}
  # proc getCurrentProcessToken(): uint =
  #   # (HANDLE)(LONG_PTR) -4;
  #   cast[uint](-4)

  proc `==`*(a: IoErrorCode, b: uint32): bool {.inline.} =
    (uint32(a) == b)

elif defined(posix):
  import posix

  const
    DirSep* = '/'
    AltSep* = '/'
    BothSeps* = {'/'}

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

  var errno {.importc, header: "<errno.h>".}: cint

  proc write(a1: cint, a2: pointer, a3: csize_t): int {.
       importc, header: "<unistd.h>".}
  proc read(a1: cint, a2: pointer, a3: csize_t): int {.
       importc, header: "<unistd.h>".}
  proc c_strlen(a: cstring): cint {.
       importc: "strlen", header: "<string.h>", noSideEffect.}
  proc c_strerror(errnum: cint): cstring {.
       importc: "strerror", header: "<string.h>".}
  proc getcwd(a1: cstring, a2: int): cstring {.
       importc, header: "<unistd.h>", sideEffect.}
  proc `==`*(a: IoErrorCode, b: cint): bool {.inline.} =
    (cint(a) == b)

type
  IoResult*[T] = Result[T, IoErrorCode]

  OpenFlags* = enum
    ReadOnly, WriteOnly, ReadWrite, Create, Exclusive, Append, Truncate,
    NoInherit, NonBlock, Direct

  Permission* = enum
    UserRead, UserWrite, UserExec,
    GroupRead, GroupWrite, GroupExec,
    OtherRead, OtherWrite, OtherExec

  Permissions* = set[Permission]

  AccessFlags* = enum
    Find, Read, Write, Execute

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
  when defined(posix):
    if code != IoErrorCode(0):
      $c_strerror(cint(code))
    else:
      ""
  elif defined(windows):
    if code != IoErrorCode(0):
      var msgbuf: WideCString
      if formatMessageW(0x00000100'u32 or 0x00001000'u32 or 0x00000200'u32,
                        nil, uint32(code), 0, addr(msgbuf), 0, nil) != 0'u32:
        var res = $msgbuf
        if not(isNil(msgbuf)):
          discard localFree(cast[pointer](msgbuf))
        res
      else:
        ""
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
    var bufsize = 1024
    var buffer = newString(bufsize)
    while true:
      if getcwd(buffer, bufsize) != nil:
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

proc rawCreateDir(dir: string, mode: int = 0o755): IoResult[bool] =
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
    let res = removeDirectoryW(newWideCString(dir))
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
    if deleteFileW(newWideCString(path)) == 0:
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

proc createPath*(path: string, createMode: int = 0o755): IoResult[void] =
  ## Creates the full path ``path`` with mode ``createMode``.
  ##
  ## Path may contain several subfolders that do not exist yet.
  ## The full path is created. If this fails, error will be returned.
  ##
  ## It does **not** fail if the folder already exists because for
  ## most usages this does not indicate an error.
  let paths = getPathItems(path, true)
  when defined(posix):
    let oldmask = posix.umask(Mode(0))
  for item in paths:
    let res = rawCreateDir(item, createMode)
    if res.isErr():
      when defined(posix):
        discard posix.umask(oldmask)
      return err(res.error)
  ok()

proc getPermissions*(pathName: string): IoResult[int] =
  ## Retreive permissions of file/folder ``pathName`` and return it as integer.
  when defined(windows):
    let res = getFileAttributes(newWideCString(pathName))
    if res == INVALID_FILE_ATTRIBUTES:
      err(ioLastError())
    else:
      if (res and FILE_ATTRIBUTE_READONLY) == FILE_ATTRIBUTE_READONLY:
        ok(0o555)
      else:
        ok(0o777)
  elif defined(posix):
    var a: posix.Stat
    let res = posix.stat(pathName, a)
    if res == 0:
      ok(int(a.st_mode) and 0o777)
    else:
      err(ioLastError())
  else:
    ok(0o777)

proc setPermissions*(pathName: string, mask: int): IoResult[void] =
  ## Set permissions for file/folder ``pathame``.
  when defined(windows):
    let gres = getFileAttributes(newWideCString(pathName))
    if gres == INVALID_FILE_ATTRIBUTES:
      err(ioLastError())
    else:
      let nmask =
        if (mask and 0o222) == 0:
          gres and uint32(FILE_ATTRIBUTE_READONLY)
        else:
          gres and not(FILE_ATTRIBUTE_READONLY)
      let sres = setFileAttributes(newWideCString(pathName), nmask)
      if sres == 0:
        err(ioLastError())
      else:
        ok()
  elif defined(posix):
    while true:
      let res = posix.chmod(pathName, Mode(mask))
      if res == 0:
        return ok()
      else:
        let errCode = ioLastError()
        if errCode == EINTR:
          continue
        else:
          return err(errCode)

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
    let res = getFileAttributes(newWideCString(pathName))
    if res == INVALID_FILE_ATTRIBUTES:
      return false
    if AccessFlags.Write in mask:
      if (res and FILE_ATTRIBUTE_READONLY) == FILE_ATTRIBUTE_READONLY:
        return false
      else:
        return true
    return true

proc getPermissionsSet*(pathName: string): IoResult[set[Permission]] =
  ## Retreive permissions of file/folder ``pathName`` and return set of
  ## ``Permission`.
  let mask = ? getPermissions(pathName)
  when defined(windows):
    if mask == 0o555:
      ok({UserRead, UserExec, GroupRead, GroupExec, OtherRead, OtherExec})
    else:
      ok({UserRead .. OtherExec})
  elif defined(posix):
    var res: set[Permission]
    if (mask and S_IRUSR) != 0: res.incl(UserRead)
    if (mask and S_IWUSR) != 0: res.incl(UserWrite)
    if (mask and S_IXUSR) != 0: res.incl(UserExec)

    if (mask and S_IRGRP) != 0: res.incl(GroupRead)
    if (mask and S_IWGRP) != 0: res.incl(GroupWrite)
    if (mask and S_IXGRP) != 0: res.incl(GroupExec)

    if (mask and S_IROTH) != 0: res.incl(OtherRead)
    if (mask and S_IWOTH) != 0: res.incl(OtherWrite)
    if (mask and S_IXOTH) != 0: res.incl(OtherExec)
    ok(res)
  else:
    ok({UserRead .. OtherExec})

proc setPermissions*(pathName: string, mask: set[Permission]): IoResult[void] =
  ## Set permissions for file/folder ``pathame`` using mask ``mask``.
  when defined(windows):
    var rnum = 0
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
    setPermissions(pathName, rnum)
  elif defined(posix):
    var rnum = 0
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
    setPermissions(pathName, rnum)
  else:
    ok()

proc toString*(mask: set[Permission]): string =
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
    var a: posix.Stat
    let res = posix.stat(pathName, a)
    if res == 0:
      (int(a.st_mode) and 0o777) == mask
    else:
      false
  else:
    true

proc openFile*(pathName: string, flags: set[OpenFlags],
               createMode: int = 0o666): IoResult[IoHandle] =
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
                data: openarray[byte]): IoResult[uint] =
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
                data: openarray[char]): IoResult[uint] {.inline.} =
  ## Write ``data`` characters to file descriptor ``handle``.
  ##
  ## Returns number of characters written.
  writeFile(handle, data.toOpenArrayByte(0, len(data) - 1))

proc readFile*(handle: IoHandle,
               data: var openarray[byte]): IoResult[uint] =
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
               data: var openarray[char]): IoResult[uint] {.inline.} =
  ## Reads ``len(data)`` characters from file descriptor ``handle`` and store
  ## this characters to ``data``.
  ##
  ## Returns number of bytes characters read from file descriptor.
  readFile(handle, data.toOpenArrayByte(0, len(data) - 1))

proc writeFile*(pathName: string, data: openarray[byte],
                createMode: int = 0o644): IoResult[void] =
  ## Opens a file named ``pathName`` for writing. Then writes the
  ## content ``data`` completely to the file and closes the file afterwards.
  ##
  ## If file is not exists it will be created with permissions mask
  ## ``createMode`` (default value is 0o644).
  ##
  ## If file is already exists, but file permissions are not equal to
  ## ``createMode`` procedure will change permissions first and only after
  ## success it will write data to file.
  if fileAccessible(pathName, {AccessFlags.Find, AccessFlags.Write}):
    let permissions = ? getPermissions(pathName)
    if permissions != createMode:
      ? setPermissions(pathName, createMode)
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
                createMode: int = 0o644): IoResult[void] {.inline.} =
  ## Opens a file named ``pathName`` for writing. Then writes the
  ## content ``data`` completely to the file and closes the file afterwards.
  ##
  ## If file is not exists it will be created with permissions mask
  ## ``createMode`` (default value is 0o644).
  writeFile(pathName, data.toOpenArrayByte(0, len(data) - 1), createMode)

proc readAllFile*(pathName: string, blockSize = 16384'u): IoResult[seq[byte]] =
  ## Opens a file named ``pathName`` for reading, reads all the data from
  ## file and closes the file afterwards. Returns sequence of bytes or error.
  doAssert(blockSize > 0'u, "blockSize must not be zero")
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
