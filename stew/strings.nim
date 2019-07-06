proc add*(s: var string, data: openarray[char]) =
  if data.len > 0:
    let prevEnd = s.len
    s.setLen(prevEnd + data.len)
    copyMem(addr s[prevEnd], unsafeAddr data[0], data.len)

