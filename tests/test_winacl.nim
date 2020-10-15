import std/unittest
import ../stew/[io2, windows/acl]

suite "Windows security descriptor tests suite":
  test "File/Folder user-only ACL create/verify test":
    when defined(windows):
      proc performTest(path1: string, path2: string): IoResult[bool] =
        var sd = ? createCurrentUserOnlySecurityDescriptor()
        # Create directory
        ? createPath(path1, secDescriptor = sd.getDescriptor())
        # Create file
        ? writeFile(path2, "TESTBLOB", secDescriptor = sd.getDescriptor())
        let res1 = ? checkCurrentUserOnlyACL(path1)
        let res2 = ? checkCurrentUserOnlyACL(path2)
        ? removeFile(path2)
        ? removeDir(path1)
        if res1 and res2:
          ok(true)
        else:
          err(IoErrorCode(UserErrorCode))
      check:
        performTest("testblob14", "testblob15").isOk()
    else:
      skip()
