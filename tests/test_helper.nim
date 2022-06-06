import std/[os, strutils]
import ../stew/io2, ../stew/results

proc lockFileFlags(path: string, flags: set[OpenFlags]): IoResult[void] =
  let flags = {OpenFlags.Read}
  let handle = ? openFile(path, flags)
  let info {.used.} = ? lockFile(handle)
  ? closeFile(handle)
  ok()

when isMainModule:
  if paramCount() != 2:
    echo "Not enough parameters"
  else:
    case paramStr(1)
    of "lock":
      const TestFlags = [
        {OpenFlags.Read},
        {OpenFlags.Write},
        {OpenFlags.Read, OpenFlags.Write},
        {OpenFlags.Read, OpenFlags.ShareRead},
        {OpenFlags.Write, OpenFlags.ShareWrite},
        {OpenFlags.Read, OpenFlags.Write,
         OpenFlags.ShareRead, OpenFlags.ShareWrite},
        {OpenFlags.Truncate, OpenFlags.Create, OpenFlags.Write,
         OpenFlags.ShareWrite}
      ]
      let pathName = paramStr(2)
      let response =
        block:
          var res: seq[string]
          for test in TestFlags:
            let
              lres = lockFileFlags(pathName, test)
              data = if lres.isOk(): "OK" else: "E" & $int(lres.error())
            res.add(data)
          res.join(":")
      echo response
    of "delete":
      let pathName = paramStr(2)
      let res = io2.removeFile(pathName)
      if res.isOk():
        echo "OK"
      else:
        echo "E" & $int(res.error())
    of "move":
      let pathName = paramStr(2)
      let res = io2.moveFile(pathName)
