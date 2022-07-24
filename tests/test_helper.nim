import std/[os, strutils]
import ../stew/io2, ../stew/results

proc lockFileFlags(path: string, flags: set[OpenFlags],
                   lockType: LockType): IoResult[void] =
  let handle = ? openFile(path, flags)
  let info = ? lockFile(handle, lockType)
  ? unlockFile(info)
  ? closeFile(handle)
  ok()

when isMainModule:
  if paramCount() != 1:
    echo "Not enough parameters"
  else:
    const TestFlags = [
      ({OpenFlags.Read}, LockType.Shared),
      ({OpenFlags.Write}, LockType.Exclusive),

      ({OpenFlags.Read, OpenFlags.Write}, LockType.Shared),
      ({OpenFlags.Read, OpenFlags.Write}, LockType.Exclusive),

      ({OpenFlags.Read, OpenFlags.ShareRead}, LockType.Shared),
      ({OpenFlags.Write, OpenFlags.ShareWrite}, LockType.Exclusive),

      ({OpenFlags.Read, OpenFlags.Write,
        OpenFlags.ShareRead, OpenFlags.ShareWrite}, LockType.Shared),
      ({OpenFlags.Read, OpenFlags.Write,
        OpenFlags.ShareRead, OpenFlags.ShareWrite}, LockType.Exclusive),
    ]
    let pathName = paramStr(1)
    let response =
      block:
        var res: seq[string]
        for test in TestFlags:
          let
            lres = lockFileFlags(pathName, test[0], test[1])
            data = if lres.isOk(): "OK" else: "E" & $int(lres.error())
          res.add(data)
        res.join(":")
    echo response
