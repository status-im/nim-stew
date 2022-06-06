import std/[os, strutils]
import ../stew/io2, ../stew/results

proc lockFileFlags(path: string, flags: set[OpenFlags]): IoResult[void] =
  let flags = {OpenFlags.Read}
  let handle = ? openFile(path, flags)
  let info {.used.} = ? lockFile(handle)
  ? closeFile(handle)
  ok()

when isMainModule:
  if paramCount() != 1:
    echo "Not enough parameters"
  else:
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
    let pathName = paramStr(1)
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
