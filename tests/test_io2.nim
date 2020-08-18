import unittest
import ../stew/io2

suite "OS Input/Output procedures test suite":
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

  test "writeFile()/readFile() test":
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
      cast[string](readAllFile("testblob1").tryGet()) == "BLOCK1"
      cast[string](readAllFile("testblob2").tryGet()) == "BLOCK2"
      cast[string](readAllFile("testblob3").tryGet()) == "BLOCK3"
      cast[string](readAllFile("testblob4").tryGet()) == "BLOCK4"
      cast[string](readAllFile("testblob5").tryGet()) == "BLOCK5"
      cast[string](readAllFile("testblob6").tryGet()) == "BLOCK6"
      removeFile("testblob1").isOk()
      removeFile("testblob2").isOk()
      removeFile("testblob3").isOk()
      removeFile("testblob4").isOk()
      removeFile("testblob5").isOk()
      removeFile("testblob6").isOk()

  test "toString(set[Permission]) test":
    let emptyMask: set[Permission] = {}
    check:
      {UserRead, UserWrite, UserExec}.toString() == "0700 (rwx------)"
      {GroupRead, GroupWrite, GroupExec}.toString() == "0070 (---rwx---)"
      {OtherRead, OtherWrite, OtherExec}.toString() == "0007 (------rwx)"
      {UserExec, GroupExec, OtherExec}.toString() == "0111 (--x--x--x)"
      {UserRead .. OtherExec}.toString() == "0777 (rwxrwxrwx)"
      emptyMask.toString() == "0000 (---------)"
