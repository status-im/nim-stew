## Copyright (c) 2020 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements cross-platform console procedures.
import io2
export io2

when defined(windows):
  proc setConsoleOutputCP(wCodePageID: cuint): int32 {.
       importc: "SetConsoleOutputCP", stdcall, dynlib: "kernel32", sideEffect.}
  proc setConsoleCP(wCodePageID: cuint): int32 {.
       importc: "SetConsoleCP", stdcall, dynlib: "kernel32", sideEffect.}
  proc getConsoleCP(): cuint {.
       importc: "GetConsoleCP", stdcall, dynlib: "kernel32", sideEffect.}
  proc getConsoleOutputCP(): cuint {.
       importc: "GetConsoleOutputCP", stdcall, dynlib: "kernel32", sideEffect.}
  proc setConsoleMode(hConsoleHandle: uint, dwMode: uint32): int32 {.
       importc: "SetConsoleMode", stdcall, dynlib: "kernel32", sideEffect.}
  proc getConsoleMode(hConsoleHandle: uint, dwMode: var uint32): int32 {.
       importc: "GetConsoleMode", stdcall, dynlib: "kernel32", sideEffect.}
  proc readConsole(hConsoleInput: uint, lpBuffer: pointer,
                   nNumberOfCharsToRead: uint32,
                   lpNumberOfCharsRead: var uint32,
                   pInputControl: pointer): int32 {.
       importc: "ReadConsoleW", stdcall, dynlib: "kernel32", sideEffect.}
  proc readFile(hFile: uint, lpBuffer: pointer,
                nNumberOfBytesToRead: uint32,
                lpNumberOfBytesRead: var uint32,
                lpOverlapped: pointer): int32 {.
       importc: "ReadFile", dynlib: "kernel32", stdcall, sideEffect.}
  proc writeConsole(hConsoleOutput: uint, lpBuffer: pointer,
                    nNumberOfCharsToWrite: uint32,
                    lpNumberOfCharsWritten: var uint32,
                    lpReserved: pointer): int32 {.
       importc: "WriteConsoleW", stdcall, dynlib: "kernel32", sideEffect.}
  proc writeFile(hFile: uint, lpBuffer: pointer,
                 nNumberOfBytesToWrite: uint32,
                 lpNumberOfBytesWritten: var uint32,
                 lpOverlapped: pointer): int32 {.
       importc: "WriteFile", dynlib: "kernel32", stdcall, sideEffect.}
  proc getStdHandle(nStdHandle: uint32): uint {.
       importc: "GetStdHandle", stdcall, dynlib: "kernel32", sideEffect.}
  proc wideCharToMultiByte(codePage: cuint, dwFlags: uint32,
                           lpWideCharStr: ptr Utf16Char, cchWideChar: cint,
                           lpMultiByteStr: ptr char, cbMultiByte: cint,
                           lpDefaultChar: pointer,
                           lpUsedDefaultChar: pointer): cint {.
       importc: "WideCharToMultiByte", stdcall, dynlib: "kernel32", sideEffect.}
  proc getFileType(hFile: uint): uint32 {.
       importc: "GetFileType", stdcall, dynlib: "kernel32", sideEffect.}

  const
    CP_UTF8 = 65001'u32
    STD_INPUT_HANDLE = cast[uint32](-10)
    STD_OUTPUT_HANDLE = cast[uint32](-11)
    INVALID_HANDLE_VALUE = cast[uint](-1)
    ENABLE_PROCESSED_INPUT = 0x0001'u32
    ENABLE_ECHO_INPUT = 0x0004'u32
    FILE_TYPE_CHAR = 0x0002'u32

  proc isConsoleRedirected(hConsole: uint): bool =
    ## Returns ``true`` if console handle was redirected.
    let res = getFileType(hConsole)
    if res == FILE_TYPE_CHAR:
      # The specified handle is a character device, typically an LPT device or a
      # console.
      false
    else:
      true

  proc readConsoleInput(maxBytes: int): IoResult[string] =
    let hConsoleInput =
      block:
        let res = getStdHandle(STD_INPUT_HANDLE)
        if res == INVALID_HANDLE_VALUE:
          return err(ioLastError())
        res

    let prevInputCP =
      block:
        let res = getConsoleCP()
        if res == cuint(0):
          return err(ioLastError())
        res

    if isConsoleRedirected(hConsoleInput):
      # Console STDIN is redirected, we should use ReadFile(), because
      # ReadConsole() is not working for such types of STDIN.
      if setConsoleCP(CP_UTF8) == 0'i32:
        return err(ioLastError())

      # Allocating buffer with size equal to `maxBytes` + len(CRLF)
      var buffer = newString(maxBytes + 2)
      let bytesToRead = uint32(len(buffer))
      var bytesRead: uint32
      let rres = readFile(hConsoleInput, cast[pointer](addr buffer[0]),
                          bytesToRead, bytesRead, nil)
      if rres == 0:
        let errCode = ioLastError()
        discard setConsoleCP(prevInputCP)
        return err(errCode)

      if setConsoleCP(prevInputCP) == 0'i32:
        return err(ioLastError())

      # Truncate additional bytes from buffer.
      buffer.setLen(int(min(bytesRead, uint32(maxBytes))))

      # Trim CR/CRLF from buffer.
      if len(buffer) > 0:
        if buffer[^1] == char(0x0A):
          if len(buffer) > 1:
            if buffer[^2] == char(0x0D):
              buffer.setLen(len(buffer) - 2)
            else:
              buffer.setLen(len(buffer) - 1)
          else:
            buffer.setLen(len(buffer) - 1)
        elif buffer[^1] == char(0x0D):
          buffer.setLen(len(buffer) - 1)
      ok(buffer)
    else:
      let prevMode =
        block:
          var mode: uint32
          let res = getConsoleMode(hConsoleInput, mode)
          if res == 0:
            return err(ioLastError())
          mode

      var newMode = prevMode or ENABLE_PROCESSED_INPUT
      newMode = newMode and not(ENABLE_ECHO_INPUT)

      # Change console CodePage to allow UTF-8 strings input.
      if setConsoleCP(CP_UTF8) == 0'i32:
        return err(ioLastError())

      # Disable local echo output.
      let mres = setConsoleMode(hConsoleInput, newMode)
      if mres == 0:
        let errCode = ioLastError()
        discard setConsoleCP(prevInputCP)
        return err(errCode)

      # Allocating buffer with size equal to `maxBytes` + len(CRLF)
      var buffer = newSeq[Utf16Char](maxBytes + 2)
      let charsToRead = uint32(len(buffer))
      var charsRead: uint32
      let rres = readConsole(hConsoleInput, cast[pointer](addr buffer[0]),
                             charsToRead, charsRead, nil)
      if rres == 0'i32:
        let errCode = ioLastError()
        discard setConsoleMode(hConsoleInput, prevMode)
        discard setConsoleCP(prevInputCP)
        return err(errCode)

      # Restore local echo output.
      if setConsoleMode(hConsoleInput, prevMode) == 0'i32:
        let errCode = ioLastError()
        discard setConsoleCP(prevInputCP)
        return err(errCode)

      # Restore previous console CodePage.
      if setConsoleCP(prevInputCP) == 0'i32:
        return err(ioLastError())

      # Truncate additional bytes from buffer.
      buffer.setLen(int(min(charsRead, uint32(maxBytes))))
      # Truncate CRLF in result wide string.
      if len(buffer) > 0:
        if int16(buffer[^1]) == int16(0x0A):
          if len(buffer) > 1:
            if int16(buffer[^2]) == int16(0x0D):
              buffer.setLen(len(buffer) - 2)
            else:
              buffer.setLen(len(buffer) - 1)
          else:
            buffer.setLen(len(buffer) - 1)
        elif int16(buffer[^1]) == int16(0x0D):
          buffer.setLen(len(buffer) - 1)

      # Convert Windows UTF-16 encoded string to UTF-8 encoded string.
      if len(buffer) > 0:
        var pwd = ""
        let bytesNeeded = wideCharToMultiByte(CP_UTF8, 0'u32, addr buffer[0],
                                              cint(len(buffer)), nil,
                                              cint(0), nil, nil)
        if bytesNeeded <= cint(0):
          return err(ioLastError())
        pwd.setLen(bytesNeeded)
        let cres = wideCharToMultiByte(CP_UTF8, 0'u32, addr buffer[0],
                                       cint(len(buffer)), addr pwd[0],
                                       cint(len(pwd)), nil, nil)
        if cres == cint(0):
          return err(ioLastError())
        ok(pwd)
      else:
        ok("")

  proc writeConsoleOutput(data: string): IoResult[void] =
    if len(data) == 0:
      return ok()

    let hConsoleOutput =
      block:
        let res = getStdHandle(STD_OUTPUT_HANDLE)
        if res == INVALID_HANDLE_VALUE:
          return err(ioLastError())
        res

    let prevOutputCP =
      block:
        let res = getConsoleOutputCP()
        if res == cuint(0):
          return err(ioLastError())
        res

    if isConsoleRedirected(hConsoleOutput):
      # If STDOUT is redirected we should use WriteFile() because WriteConsole()
      # is not working for such types of STDOUT.
      if setConsoleOutputCP(CP_UTF8) == 0'i32:
        return err(ioLastError())

      let bytesToWrite = uint32(len(data))
      var bytesWritten: uint32
      let wres = writeFile(hConsoleOutput, cast[pointer](unsafeAddr data[0]),
                           bytesToWrite, bytesWritten, nil)
      if wres == 0'i32:
        let errCode = ioLastError()
        discard setConsoleOutputCP(prevOutputCP)
        return err(errCode)

      if setConsoleOutputCP(prevOutputCP) == 0'i32:
        return err(ioLastError())
    else:
      if setConsoleOutputCP(CP_UTF8) == 0'i32:
        return err(ioLastError())

      let widePrompt = newWideCString(data)
      var charsWritten: uint32
      let wres = writeConsole(hConsoleOutput, cast[pointer](widePrompt),
                              uint32(len(widePrompt)), charsWritten, nil)
      if wres == 0'i32:
        let errCode = ioLastError()
        discard setConsoleOutputCP(prevOutputCP)
        return err(errCode)

      if setConsoleOutputCP(prevOutputCP) == 0'i32:
        return err(ioLastError())
    ok()

elif defined(posix):
  import posix, termios

  proc isConsoleRedirected(consoleFd: cint): bool =
    ## Returns ``true`` if console handle was redirected.
    var mode: Termios
    # This is how `isatty()` checks for TTY.
    if tcGetAttr(consoleFd, addr mode) != cint(0):
      true
    else:
      false

  proc writeConsoleOutput(prompt: string): IoResult[void] =
    if len(prompt) == 0:
      ok()
    else:
      let res = posix.write(STDOUT_FILENO, cast[pointer](unsafeAddr prompt[0]),
                            len(prompt))
      if res != len(prompt):
        err(ioLastError())
      else:
        ok()

  proc readConsoleInput(maxBytes: int): IoResult[string] =
    # Allocating buffer with size equal to `maxBytes` + len(LF)
    var buffer = newString(maxBytes + 1)
    let bytesRead =
      if isConsoleRedirected(STDIN_FILENO):
        let res = posix.read(STDIN_FILENO, cast[pointer](addr buffer[0]),
                             len(buffer))
        if res < 0:
          return err(ioLastError())
        res
      else:
        var cur, old: Termios
        if tcGetAttr(STDIN_FILENO, addr cur) != cint(0):
          return err(ioLastError())

        old = cur
        cur.c_lflag = cur.c_lflag and not(Cflag(ECHO))

        if tcSetAttr(STDIN_FILENO, TCSADRAIN, addr(cur)) != cint(0):
          return err(ioLastError())

        let res = read(STDIN_FILENO, cast[pointer](addr buffer[0]),
                       len(buffer))
        if res < 0:
          let errCode = ioLastError()
          discard tcSetAttr(STDIN_FILENO, TCSADRAIN, addr(old))
          return err(errCode)

        if tcSetAttr(STDIN_FILENO, TCSADRAIN, addr(old)) != cint(0):
          return err(ioLastError())
        res

    # Truncate additional bytes from buffer.
    buffer.setLen(min(maxBytes, bytesRead))
    # Trim LF in result string
    if len(buffer) > 0:
      if buffer[^1] == char(0x0A):
        buffer.setLen(len(buffer) - 1)
    ok(buffer)

proc readConsolePassword*(prompt: string,
                          maxBytes = 32768): IoResult[string] =
  ## Reads a password from stdin without printing it with length in bytes up to
  ## ``maxBytes``.
  ##
  ## This procedure supports reading of UTF-8 encoded passwords from console or
  ## redirected pipe. But ``maxBytes`` will limit
  ##
  ## Before reading password ``prompt`` will be printed.
  ##
  ## Please note that ``maxBytes`` should be in range (0, 32768].
  doAssert(maxBytes > 0 and maxBytes <= 32768,
           "maxBytes should be integer in (0, 32768]")
  ? writeConsoleOutput(prompt)
  let res = ? readConsoleInput(maxBytes)
  # `\p` is platform specific newline: CRLF on Windows, LF on Unix
  ? writeConsoleOutput("\p")
  ok(res)
