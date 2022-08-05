# Copyright (c) 2020-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import unittest2
import std/[osproc, strutils]
import ../stew/io2

when defined(posix):
  from std/posix import EAGAIN

suite "OS Input/Output procedures test suite":
  test "getCurrentDir() test":
    let res = getCurrentDir()
    check:
      res.isOk() == true
      len(res.get()) > 0
  test "splitDrive() test":
    when defined(windows):
      check:
        splitDrive("c:\\foo\\bar") == ("c:", "\\foo\\bar")
        splitDrive("c:/foo/bar") == ("c:", "/foo/bar")
        splitDrive("\\\\conky\\mountpoint\\foo\\bar") ==
          ("\\\\conky\\mountpoint", "\\foo\\bar")
        splitDrive("//conky/mountpoint/foo/bar") ==
          ("//conky/mountpoint", "/foo/bar")
        splitDrive("\\\\\\conky\\mountpoint\\foo\\bar") ==
          ("", "\\\\\\conky\\mountpoint\\foo\\bar")
        splitDrive("///conky/mountpoint/foo/bar") ==
          ("", "///conky/mountpoint/foo/bar")
        splitDrive("\\\\conky\\\\mountpoint\\foo\\bar") ==
          ("", "\\\\conky\\\\mountpoint\\foo\\bar")
        splitDrive("//conky//mountpoint/foo/bar") ==
          ("", "//conky//mountpoint/foo/bar")
        splitDrive("") == ("", "")
        splitDrive("C") == ("", "C")
        splitDrive("C:") == ("C:", "")
        splitDrive("\\") == ("", "\\")
        splitDrive("\\\\") == ("", "\\\\")
        splitDrive("\\\\\\") == ("", "\\\\\\")
        splitDrive("/") == ("", "/")
        splitDrive("//") == ("", "//")
        splitDrive("///") == ("", "///")
        splitDrive("//conky/MOUNTPOİNT/foo/bar") ==
          ("//conky/MOUNTPOİNT", "/foo/bar")
    elif defined(posix):
      check:
        splitDrive("c:\\foo\\bar") == ("", "c:\\foo\\bar")
        splitDrive("c:/foo/bar") == ("", "c:/foo/bar")
        splitDrive("\\\\conky\\mountpoint\\foo\\bar") ==
          ("", "\\\\conky\\mountpoint\\foo\\bar")
        splitDrive("") == ("", "")
        splitDrive("C") == ("", "C")
        splitDrive("C:") == ("", "C:")
        splitDrive("\\") == ("", "\\")
        splitDrive("\\\\") == ("", "\\\\")
        splitDrive("\\\\\\") == ("", "\\\\\\")
        splitDrive("/") == ("", "/")
        splitDrive("//") == ("", "//")
        splitDrive("///") == ("", "///")
        splitDrive("//conky/MOUNTPOİNT/foo/bar") ==
          ("", "//conky/MOUNTPOİNT/foo/bar")
    else:
      skip()

  test "splitPath() test":
    when defined(windows):
      check:
        splitPath("c:\\foo\\bar") == ("c:\\foo", "bar")
        splitPath("\\\\conky\\mountpoint\\foo\\bar") ==
          ("\\\\conky\\mountpoint\\foo", "bar")
        splitPath("c:\\") == ("c:\\", "")
        splitPath("\\\\conky\\mountpoint\\") ==
          ("\\\\conky\\mountpoint\\", "")
        splitPath("c:/") == ("c:/", "")
        splitPath("//conky/mountpoint/") == ("//conky/mountpoint/", "")
    elif defined(posix):
      check:
        splitPath("/foo/bar") == ("/foo", "bar")
        splitPath("/") == ("/", "")
        splitPath("foo") == ("", "foo")
        splitPath("////foo") == ("////", "foo")
        splitPath("//foo//bar") == ("//foo", "bar")
    else:
      skip()

  test "createPath()/removeDir() test":
    let curdir = getCurrentDir().tryGet()
    when defined(windows):
      let
        path13s = curdir & "\\s1\\s2\\s3"
        path12s = curdir & "\\s1\\s2"
        path11s = curdir & "\\s1"
        path23s = curdir & "\\s4\\s5\\s6"
        path22s = curdir & "\\s4\\s5"
        path21s = curdir & "\\s4"
        path33s = curdir & "\\s7\\s8\\s9"
        path32s = curdir & "\\s7\\s8"
        path31s = curdir & "\\s7"
        path13d = "d1\\d2\\d3"
        path12d = "d1\\d2"
        path11d = "d1"
        path23d = "d4\\d5\\d6"
        path22d = "d4\\d5"
        path21d = "d4"
        path33d = "d7\\d8\\d9"
        path32d = "d7\\d8"
        path31d = "d7"
    elif defined(posix):
      let
        path13s = curdir & "/s1/s2/s3"
        path12s = curdir & "/s1/s2"
        path11s = curdir & "/s1"
        path23s = curdir & "/s4/s5/s6"
        path22s = curdir & "/s4/s5"
        path21s = curdir & "/s4"
        path33s = curdir & "/s7/s8/s9"
        path32s = curdir & "/s7/s8"
        path31s = curdir & "/s7"
        path13d = "d1/d2/d3"
        path12d = "d1/d2"
        path11d = "d1"
        path23d = "d4/d5/d6"
        path22d = "d4/d5"
        path21d = "d4"
        path33d = "d7/d8/d9"
        path32d = "d7/d8"
        path31d = "d7"

    check:
      createPath(path13s, 0o700).isOk()
      createPath(path23s, 0o775).isOk()
      createPath(path33s, 0o777).isOk()
      createPath(path13d, 0o770).isOk()
      createPath(path23d, 0o752).isOk()
      createPath(path33d, 0o772).isOk()
      checkPermissions(path13s, 0o700) == true
      checkPermissions(path23s, 0o775) == true
      checkPermissions(path33s, 0o777) == true
      checkPermissions(path13d, 0o770) == true
      checkPermissions(path23d, 0o752) == true
      checkPermissions(path33d, 0o772) == true
      removeDir(path13s).isOk()
      removeDir(path12s).isOk()
      removeDir(path11s).isOk()
      removeDir(path23s).isOk()
      removeDir(path22s).isOk()
      removeDir(path21s).isOk()
      removeDir(path33s).isOk()
      removeDir(path32s).isOk()
      removeDir(path31s).isOk()
      removeDir(path13d).isOk()
      removeDir(path12d).isOk()
      removeDir(path11d).isOk()
      removeDir(path23d).isOk()
      removeDir(path22d).isOk()
      removeDir(path21d).isOk()
      removeDir(path33d).isOk()
      removeDir(path32d).isOk()
      removeDir(path31d).isOk()

  test "writeFile() to existing file with different permissions":
    check:
      writeFile("testblob0", "BLOCK0", 0o666).isOk()
      checkPermissions("testblob0", 0o666) == true
      writeFile("testblob0", "BLOCK1", 0o600).isOk()
      checkPermissions("testblob0", 0o600) == true
      writeFile("testblob0", "BLOCK2", 0o777).isOk()
      checkPermissions("testblob0", 0o777) == true
      removeFile("testblob0").isOk()

  test "setPermissions(handle)/getPermissions(handle)":
    proc performTest(pathName: string,
                     permissions: int): IoResult[int] =
      let msg = "BLOCK"
      let flags = {OpenFlags.Write, OpenFlags.Truncate, OpenFlags.Create}
      let handle = ? openFile(pathName, flags)
      let wcount {.used.} = ? writeFile(handle, msg)
      let oldPermissions = ? getPermissions(handle)
      ? setPermissions(handle, permissions)
      let permissions = ? getPermissions(handle)
      ? setPermissions(handle, oldPermissions)
      ? closeFile(handle)
      ? removeFile(pathName)
      ok(permissions)

    let r000 = performTest("testblob0", 0o000)

    let r100 = performTest("testblob0", 0o100)
    let r200 = performTest("testblob0", 0o200)
    let r300 = performTest("testblob0", 0o300)
    let r400 = performTest("testblob0", 0o400)
    let r500 = performTest("testblob0", 0o500)
    let r600 = performTest("testblob0", 0o600)
    let r700 = performTest("testblob0", 0o700)

    let r010 = performTest("testblob0", 0o010)
    let r020 = performTest("testblob0", 0o020)
    let r030 = performTest("testblob0", 0o030)
    let r040 = performTest("testblob0", 0o040)
    let r050 = performTest("testblob0", 0o050)
    let r060 = performTest("testblob0", 0o060)
    let r070 = performTest("testblob0", 0o070)

    let r001 = performTest("testblob0", 0o001)
    let r002 = performTest("testblob0", 0o002)
    let r003 = performTest("testblob0", 0o003)
    let r004 = performTest("testblob0", 0o004)
    let r005 = performTest("testblob0", 0o005)
    let r006 = performTest("testblob0", 0o006)
    let r007 = performTest("testblob0", 0o007)

    when defined(windows):
      check:
        r000.tryGet() == 0o555
        r100.tryGet() == 0o555
        r200.tryGet() == 0o777
        r300.tryGet() == 0o777
        r400.tryGet() == 0o555
        r500.tryGet() == 0o555
        r600.tryGet() == 0o777
        r700.tryGet() == 0o777
        r010.tryGet() == 0o555
        r020.tryGet() == 0o777
        r030.tryGet() == 0o777
        r040.tryGet() == 0o555
        r050.tryGet() == 0o555
        r060.tryGet() == 0o777
        r070.tryGet() == 0o777
        r001.tryGet() == 0o555
        r002.tryGet() == 0o777
        r003.tryGet() == 0o777
        r004.tryGet() == 0o555
        r005.tryGet() == 0o555
        r006.tryGet() == 0o777
        r007.tryGet() == 0o777
    else:
      check:
        r000.tryGet() == 0o000
        r100.tryGet() == 0o100
        r200.tryGet() == 0o200
        r300.tryGet() == 0o300
        r400.tryGet() == 0o400
        r500.tryGet() == 0o500
        r600.tryGet() == 0o600
        r700.tryGet() == 0o700
        r010.tryGet() == 0o010
        r020.tryGet() == 0o020
        r030.tryGet() == 0o030
        r040.tryGet() == 0o040
        r050.tryGet() == 0o050
        r060.tryGet() == 0o060
        r070.tryGet() == 0o070
        r001.tryGet() == 0o001
        r002.tryGet() == 0o002
        r003.tryGet() == 0o003
        r004.tryGet() == 0o004
        r005.tryGet() == 0o005
        r006.tryGet() == 0o006
        r007.tryGet() == 0o007

  test "setPermissions(path)/getPermissions(path)":
    proc performTest(pathName: string,
                     permissions: int): IoResult[int] =
      let msg = "BLOCK"
      ? io2.writeFile(pathName, msg)
      let oldPermissions = ? getPermissions(pathName)
      ? setPermissions(pathName, permissions)
      let permissions = ? getPermissions(pathName)
      ? setPermissions(pathName, oldPermissions)
      ? removeFile(pathName)
      ok(permissions)

    let r000 = performTest("testblob1", 0o000)

    let r100 = performTest("testblob1", 0o100)
    let r200 = performTest("testblob1", 0o200)
    let r300 = performTest("testblob1", 0o300)
    let r400 = performTest("testblob1", 0o400)
    let r500 = performTest("testblob1", 0o500)
    let r600 = performTest("testblob1", 0o600)
    let r700 = performTest("testblob1", 0o700)

    let r010 = performTest("testblob1", 0o010)
    let r020 = performTest("testblob1", 0o020)
    let r030 = performTest("testblob1", 0o030)
    let r040 = performTest("testblob1", 0o040)
    let r050 = performTest("testblob1", 0o050)
    let r060 = performTest("testblob1", 0o060)
    let r070 = performTest("testblob1", 0o070)

    let r001 = performTest("testblob1", 0o001)
    let r002 = performTest("testblob1", 0o002)
    let r003 = performTest("testblob1", 0o003)
    let r004 = performTest("testblob1", 0o004)
    let r005 = performTest("testblob1", 0o005)
    let r006 = performTest("testblob1", 0o006)
    let r007 = performTest("testblob1", 0o007)

    when defined(windows):
      check:
        r000.tryGet() == 0o555
        r100.tryGet() == 0o555
        r200.tryGet() == 0o777
        r300.tryGet() == 0o777
        r400.tryGet() == 0o555
        r500.tryGet() == 0o555
        r600.tryGet() == 0o777
        r700.tryGet() == 0o777
        r010.tryGet() == 0o555
        r020.tryGet() == 0o777
        r030.tryGet() == 0o777
        r040.tryGet() == 0o555
        r050.tryGet() == 0o555
        r060.tryGet() == 0o777
        r070.tryGet() == 0o777
        r001.tryGet() == 0o555
        r002.tryGet() == 0o777
        r003.tryGet() == 0o777
        r004.tryGet() == 0o555
        r005.tryGet() == 0o555
        r006.tryGet() == 0o777
        r007.tryGet() == 0o777
    else:
      check:
        r000.tryGet() == 0o000
        r100.tryGet() == 0o100
        r200.tryGet() == 0o200
        r300.tryGet() == 0o300
        r400.tryGet() == 0o400
        r500.tryGet() == 0o500
        r600.tryGet() == 0o600
        r700.tryGet() == 0o700
        r010.tryGet() == 0o010
        r020.tryGet() == 0o020
        r030.tryGet() == 0o030
        r040.tryGet() == 0o040
        r050.tryGet() == 0o050
        r060.tryGet() == 0o060
        r070.tryGet() == 0o070
        r001.tryGet() == 0o001
        r002.tryGet() == 0o002
        r003.tryGet() == 0o003
        r004.tryGet() == 0o004
        r005.tryGet() == 0o005
        r006.tryGet() == 0o006
        r007.tryGet() == 0o007

  test "writeFile()/read[File(),AllBytes(),AllChars(),AllFile()] test":
    check:
      writeFile("testblob1", "BLOCK1", 0o600).isOk()
      writeFile("testblob2", "BLOCK2", 0o660).isOk()
      writeFile("testblob3", "BLOCK3", 0o666).isOk()
      writeFile("testblob4", "BLOCK4", 0o700).isOk()
      writeFile("testblob5", "BLOCK5", 0o770).isOk()
      writeFile("testblob6", "BLOCK6", 0o777).isOk()
      checkPermissions("testblob1", 0o600) == true
      checkPermissions("testblob2", 0o660) == true
      checkPermissions("testblob3", 0o666) == true
      checkPermissions("testblob4", 0o700) == true
      checkPermissions("testblob5", 0o770) == true
      checkPermissions("testblob6", 0o777) == true
    check:
      readAllChars("testblob1").tryGet() == "BLOCK1"
    block:
      # readFile(path, var openArray[byte])
      var data = newSeq[byte](6)
      check:
        readFile("testblob2", data.toOpenArray(0, len(data) - 1)).tryGet() ==
          6'u
        data == @[66'u8, 76'u8, 79'u8, 67'u8, 75'u8, 50'u8]
    block:
      # readFile(path, var openArray[char])
      var data = newString(6)
      check:
        readFile("testblob3", data.toOpenArray(0, len(data) - 1)).tryGet() ==
          6'u
        data == "BLOCK3"
    block:
      # readFile(path, var seq[byte])
      var data: seq[byte]
      check:
        readFile("testblob4", data).isOk()
        data == @[66'u8, 76'u8, 79'u8, 67'u8, 75'u8, 52'u8]
    block:
      # readFile(path, var string)
      var data: string
      check:
        readFile("testblob5", data).isOk()
        data == "BLOCK5"
    check:
      readAllBytes("testblob6").tryGet() ==
        @[66'u8, 76'u8, 79'u8, 67'u8, 75'u8, 54'u8]
    check:
      removeFile("testblob1").isOk()
      removeFile("testblob2").isOk()
      removeFile("testblob3").isOk()
      removeFile("testblob4").isOk()
      removeFile("testblob5").isOk()
      removeFile("testblob6").isOk()

  test "openFile()/readFile()/writeFile() test":
    var buffer = newString(10)
    let flags = {OpenFlags.Write, OpenFlags.Truncate, OpenFlags.Create}

    var fdres = openFile("testfile.txt", flags)
    check:
      fdres.isOk()
      readFile(fdres.get(), buffer).isErr()
      writeFile(fdres.get(), "TEST").isOk()
      readFile(fdres.get(), buffer).isErr()
      closeFile(fdres.get()).isOk()

    fdres = openFile("testfile.txt", {OpenFlags.Read})
    check:
      fdres.isOk()
      readFile(fdres.get(), buffer).isOk()
      writeFile(fdres.get(), "TEST2").isErr()
      readFile(fdres.get(), buffer).isOk()
      closeFile(fdres.get()).isOk()

    fdres = openFile("testfile.txt", {OpenFlags.Read, OpenFlags.Write})
    check:
      fdres.isOk()
      readFile(fdres.get(), buffer).isOk()
      writeFile(fdres.get(), "TEST2").isOk()
      closeFile(fdres.get()).isOk()

    check:
      removeFile("testfile.txt").isOk()

  test "toString(set[Permission]) test":
    let emptyMask: set[Permission] = {}
    check:
      {UserRead, UserWrite, UserExec}.toString() == "0700 (rwx------)"
      {GroupRead, GroupWrite, GroupExec}.toString() == "0070 (---rwx---)"
      {OtherRead, OtherWrite, OtherExec}.toString() == "0007 (------rwx)"
      {UserExec, GroupExec, OtherExec}.toString() == "0111 (--x--x--x)"
      {UserRead .. OtherExec}.toString() == "0777 (rwxrwxrwx)"
      emptyMask.toString() == "0000 (---------)"

  test "toInt(set[Permission]) test":
    let emptyMask: set[Permission] = {}
    check:
      {UserRead, UserWrite, UserExec}.toInt() == 0o700
      {GroupRead, GroupWrite, GroupExec}.toInt() == 0o070
      {OtherRead, OtherWrite, OtherExec}.toInt() == 0o007
      {UserExec, GroupExec, OtherExec}.toInt() == 0o111
      {UserRead .. OtherExec}.toInt() == 0o777
      emptyMask.toInt() == 0o000

  test "set[Permission].toPermissions(int) test":
    check:
      0o700.toPermissions() == {UserRead, UserWrite, UserExec}
      0o070.toPermissions() == {GroupRead, GroupWrite, GroupExec}
      0o007.toPermissions() == {OtherRead, OtherWrite, OtherExec}
      0o111.toPermissions() == {UserExec, GroupExec, OtherExec}
      0o777.toPermissions() == {UserRead .. OtherExec}
      0o000.toPermissions() == {}

  test "getFileSize(handle)/getFileSize(path) test":
    proc performTest(path: string): IoResult[
                                      tuple[s0, s1, s2, s3, s4: int64]
                                    ] =
      let flags = {OpenFlags.Write, OpenFlags.Truncate, OpenFlags.Create}
      let handle = ? openFile(path, flags)
      let psize0 = ? getFileSize(path)
      let hsize0 = ? getFileSize(handle)
      let msg = "BLOCK"
      discard ? io2.writeFile(handle, msg)
      let psize1 = ? getFileSize(path)
      let hsize1 = ? getFileSize(handle)
      ? closeFile(handle)
      let psize2 = ? getFileSize(path)
      ? removeFile(path)
      ok((psize0, hsize0, psize1, hsize1, psize2))

    let res = performTest("testblob2")
    check res.isOk()
    let sizes = res.get()
    when defined(windows):
      check:
        sizes[0] == 0'i64
        sizes[1] == 0'i64
        sizes[2] == 0'i64
        sizes[3] == 5'i64
        sizes[4] == 5'i64
    elif defined(posix):
      check:
        sizes[0] == 0'i64
        sizes[1] == 0'i64
        sizes[2] == 5'i64
        sizes[3] == 5'i64
        sizes[4] == 5'i64

  test "getFilePos(handle)/setFilePos(handle) test":
    proc performTest(path: string): IoResult[
                                      tuple[s0, s1, s2, s3, s4: int64]
                                    ] =
      let flags = {OpenFlags.Write, OpenFlags.Truncate, OpenFlags.Create}
      let handle = ? openFile(path, flags)
      let pos0 = ? getFilePos(handle)
      let msg = "AAAAABBBBBCCCCCDDDDD"
      discard ? io2.writeFile(handle, msg)
      let pos1 = ? getFilePos(handle)
      ? setFilePos(handle, 0'i64, SeekBegin)
      let pos2 = ? getFilePos(handle)
      ? setFilePos(handle, 10'i64, SeekCurrent)
      let pos3 = ? getFilePos(handle)
      ? setFilePos(handle, 0'i64, SeekEnd)
      let pos4 = ? getFilePos(handle)
      ? closeFile(handle)
      ? removeFile(path)
      ok((pos0, pos1, pos2, pos3, pos4))
    let res = performTest("testblob3")
    check res.isOk()
    let positions = res.get()
    check:
      positions[0] == 0'i64
      positions[1] == 20'i64
      positions[2] == 0'i64
      positions[3] == 10'i64
      positions[4] == 20'i64

  test "lockFile(handle)/unlockFile(handle) test":
    type
      TestResult = object
        output: string
        status: int

    proc createLockFile(path: string): IoResult[void] =
      io2.writeFile(path, "LOCKFILEDATA")

    proc removeLockFile(path: string): IoResult[void] =
      io2.removeFile(path)

    proc lockTest(path: string, flags: set[OpenFlags],
                  lockType: LockType): IoResult[array[3, TestResult]] =
      const HelperPath =
        when defined(windows):
          "test_helper "
        else:
          "tests/test_helper "
      let
        handle = ? openFile(path, flags)
        lock = ? lockFile(handle, lockType)
      let res1 =
        try:
          execCmdEx(HelperPath & path)
        except CatchableError as exc:
          echo "Exception happens [", $exc.name, "]: ", $exc.msg
          ("", -1)
      ? unlockFile(lock)
      let res2 =
        try:
          execCmdEx(HelperPath & path)
        except CatchableError as exc:
          echo "Exception happens [", $exc.name, "]: ", $exc.msg
          ("", -1)
      ? closeFile(handle)
      let res3 =
        try:
          execCmdEx(HelperPath & path)
        except CatchableError as exc:
          echo "Exception happens [", $exc.name, "]: ", $exc.msg
          ("", -1)
      ok([
        TestResult(output: strip(res1.output), status: res1.exitCode),
        TestResult(output: strip(res2.output), status: res2.exitCode),
        TestResult(output: strip(res3.output), status: res3.exitCode),
      ])

    proc performTest(): IoResult[void] =
      let path1 = "testfile.lock"

      when defined(windows):
        const
          ERROR_LOCK_VIOLATION = 33
          ERROR_SHARING_VIOLATION = 32
        let
          LockTests = [
            (
              {OpenFlags.Read},
              LockType.Shared,
              "OK:E$1:E$1:E$1:OK:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "OK:E$1:E$1:E$1:OK:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Write},
              LockType.Exclusive,
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Read, OpenFlags.Write},
              LockType.Shared,
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Read, OpenFlags.Write},
              LockType.Exclusive,
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Read, OpenFlags.ShareRead},
              LockType.Shared,
              "OK:E$1:E$1:E$1:OK:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "OK:E$1:E$1:E$1:OK:E$1:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Write, OpenFlags.ShareWrite},
              LockType.Exclusive,
              "E$1:E$1:E$1:E$1:E$1:E$2:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION, $ERROR_LOCK_VIOLATION],
              "E$1:E$1:E$1:E$1:E$1:OK:E$1:E$1" %
                [$ERROR_SHARING_VIOLATION],
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Read, OpenFlags.Write, OpenFlags.ShareRead,
               OpenFlags.ShareWrite},
              LockType.Shared,
              "E$1:E$1:E$1:E$1:E$1:E$1:OK:E$2" %
                [$ERROR_SHARING_VIOLATION, $ERROR_LOCK_VIOLATION],
              "E$1:E$1:E$1:E$1:E$1:E$1:OK:OK" %
                [$ERROR_SHARING_VIOLATION],
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Read, OpenFlags.Write, OpenFlags.ShareRead,
               OpenFlags.ShareWrite},
              LockType.Exclusive,
              "E$1:E$1:E$1:E$1:E$1:E$1:E$2:E$2" %
                [$ERROR_SHARING_VIOLATION, $ERROR_LOCK_VIOLATION],
              "E$1:E$1:E$1:E$1:E$1:E$1:OK:OK" %
                [$ERROR_SHARING_VIOLATION],
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
          ]
      else:
        let
          LockTests = [
            (
              {OpenFlags.Read},
              LockType.Shared,
              "OK:E$1:OK:E$1:OK:E$1:OK:E$1" % [$EAGAIN],
              "OK:OK:OK:OK:OK:OK:OK:OK",
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Write},
              LockType.Exclusive,
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" % [$EAGAIN],
              "OK:OK:OK:OK:OK:OK:OK:OK",
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Read, OpenFlags.Write},
              LockType.Shared,
              "OK:E$1:OK:E$1:OK:E$1:OK:E$1" % [$EAGAIN],
              "OK:OK:OK:OK:OK:OK:OK:OK",
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Read, OpenFlags.Write},
              LockType.Exclusive,
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" % [$EAGAIN],
              "OK:OK:OK:OK:OK:OK:OK:OK",
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Read, OpenFlags.ShareRead},
              LockType.Shared,
              "OK:E$1:OK:E$1:OK:E$1:OK:E$1" % [$EAGAIN],
              "OK:OK:OK:OK:OK:OK:OK:OK",
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Write, OpenFlags.ShareWrite},
              LockType.Exclusive,
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" % [$EAGAIN],
              "OK:OK:OK:OK:OK:OK:OK:OK",
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
            (
              {OpenFlags.Read, OpenFlags.Write, OpenFlags.ShareRead,
               OpenFlags.ShareWrite},
              LockType.Shared,
              "OK:E$1:OK:E$1:OK:E$1:OK:E$1" % [$EAGAIN],
              "OK:OK:OK:OK:OK:OK:OK:OK",
              "OK:OK:OK:OK:OK:OK:OK:OK",
            ),
            (
              {OpenFlags.Read, OpenFlags.Write, OpenFlags.ShareRead,
               OpenFlags.ShareWrite},
              LockType.Exclusive,
              "E$1:E$1:E$1:E$1:E$1:E$1:E$1:E$1" % [$EAGAIN],
              "OK:OK:OK:OK:OK:OK:OK:OK",
              "OK:OK:OK:OK:OK:OK:OK:OK"
            ),
          ]

      ? createLockFile(path1)
      for item in LockTests:
        let res = ? lockTest(path1, item[0], item[1])
        check:
          res[0].status == 0
          res[1].status == 0
          res[2].status == 0
          res[0].output == item[2]
          res[1].output == item[3]
          res[2].output == item[4]
      ? removeLockFile(path1)
      ok()

    check performTest().isOk()
