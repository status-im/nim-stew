import std/unittest
import ../stew/io2

when defined(windows):
  import ../stew/windows/acl

suite "Windows security descriptor tests suite":
  test "File/Folder user-only ACL create/verify test":
    when defined(windows):
      proc performTest(path1: string, path2: string): IoResult[bool] =
        let path3 = path1 & "\\" & path1
        let path4 = path1 & "\\" & path2
        var sdd = ? createFoldersUserOnlySecurityDescriptor()
        var sdf = ? createFilesUserOnlySecurityDescriptor()
        # Create directory
        ? createPath(path1, secDescriptor = sdd.getDescriptor())
        # Create file outside of directory
        ? writeFile(path2, "TESTBLOB", secDescriptor = sdf.getDescriptor())
        # Create directory inside of directory
        ? createPath(path3, secDescriptor = sdd.getDescriptor())
        # Create file inside of directory
        ? writeFile(path4, "TESTLBOB", secDescriptor = sdf.getDescriptor())
        let res1 = ? checkCurrentUserOnlyACL(path1)
        let res2 = ? checkCurrentUserOnlyACL(path2)
        let res3 = ? checkCurrentUserOnlyACL(path3)
        let res4 = ? checkCurrentUserOnlyACL(path4)
        ? removeFile(path4)
        ? removeDir(path3)
        ? removeFile(path2)
        ? removeDir(path1)
        if res1 and res2 and res3 and res4:
          ok(true)
        else:
          err(IoErrorCode(UserErrorCode))
      check:
        performTest("testblob14", "testblob15").isOk()
    else:
      skip()
