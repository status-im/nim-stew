import ./assign2

proc add*(s: var string, data: openArray[char]) =
  if data.len > 0:
    let prevEnd = s.len
    s.setLen(prevEnd + data.len)
    assign(s.toOpenArray(prevEnd, s.high), data)
