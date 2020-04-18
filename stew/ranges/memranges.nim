{.deprecated: "unattractive memory unsafety - use openArray and other techniques instead".}

import
  ptr_arith

type
  MemRange* = object
    start: pointer
    size: csize

template len*(mr: MemRange): int = mr.size
template `[]`*(mr: MemRange, idx: int): byte = (cast[ptr byte](shift(mr.start, idx)))[]
proc baseAddr*(mr: MemRange): pointer = mr.start

proc makeMemRange*(start: pointer, size: csize): MemRange =
  result.start = start
  result.size = size

proc toMemRange*(x: string): MemRange =
  result.start = x.cstring.pointer
  result.size = x.len

proc toMemRange*[T](x: openarray[T], fromIdx, toIdx: int): MemRange =
  doAssert(fromIdx >= 0 and toIdx >= fromIdx and fromIdx < x.len and toIdx < x.len)
  result.start = unsafeAddr x[fromIdx]
  result.size = (toIdx - fromIdx + 1) * T.sizeof

proc toMemRange*[T](x: openarray[T], fromIdx: int): MemRange {.inline.} =
  toMemRange(x, fromIdx, x.high)

proc toMemRange*[T](x: openarray[T]): MemRange {.inline.} =
  toMemRange(x, 0, x.high)

template toMemRange*(mr: MemRange): MemRange = mr
