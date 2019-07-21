import
  bitops2

type
  Bytes = seq[byte]
  BitSeq* = distinct Bytes

  BitArray*[bits: static int] = object
    bytes*: array[(bits + 7) div 8, byte]

proc len*(s: BitSeq): int =
  let
    bytesCount = s.Bytes.len
    lastByte = s.Bytes[bytesCount - 1]
    markerPos = log2trunc(lastByte)

  Bytes(s).len * 8 - (8 - markerPos)

template bytes*(s: BitSeq): untyped =
  Bytes(s)

proc add*(s: var BitSeq, value: bool) =
  let
    lastBytePos = s.Bytes.len - 1
    lastByte = s.Bytes[lastBytePos]

  if (lastByte and byte(128)) == 0:
    # There is at least one leading zero, so we have enough
    # room to store the new bit
    let markerPos = log2trunc(lastByte)
    s.Bytes[lastBytePos].setBit markerPos, value
    s.Bytes[lastBytePos].raiseBit markerPos + 1
  else:
    s.Bytes[lastBytePos].setBit 7, value
    s.Bytes.add byte(1)

proc `[]`*(s: BitSeq, pos: Natural): bool {.inline.} =
  doAssert pos < s.len
  s.Bytes.getBit pos

proc `[]=`*(s: var BitSeq, pos: Natural, value: bool) {.inline.} =
  doAssert pos < s.len
  s.Bytes.setBit pos, value

proc raiseBit*(s: var BitSeq, pos: Natural) {.inline.} =
  doAssert pos < s.len
  raiseBit s.Bytes, pos

proc lowerBit*(s: var BitSeq, pos: Natural) {.inline.} =
  doAssert pos < s.len
  lowerBit s.Bytes, pos

proc init*(T: type BitSeq, len: int): T =
  result = BitSeq newSeq[byte](1 + len div 8)
  Bytes(result).raiseBit len

proc init*(T: type BitArray): T =
  # The default zero-initializatio is fine
  discard

template `[]`*(a: BitArray, pos: Natural): bool =
  getBit a.bytes, pos

template `[]=`*(a: var BitArray, pos: Natural, value: bool) =
  setBit a.bytes, pos, value

template raiseBit*(a: var BitArray, pos: Natural) =
  raiseBit a.bytes, pos

template lowerBit*(a: var BitArray, pos: Natural) =
  lowerBit a.bytes, pos

# TODO: Submit this to the standard library as `cmp`
# At the moment, it doesn't work quite well because Nim selects
# the generic cmp[T] from the system module instead of choosing
# the openarray overload
proc compareArrays[T](a, b: openarray[T]): int =
  result = cmp(a.len, b.len)
  if result != 0: return

  for i in 0 ..< a.len:
    result = cmp(a[i], b[i])
    if result != 0: return

template cmp*(a, b: BitSeq): int =
  compareArrays(Bytes a, Bytes b)

template `==`*(a, b: BitSeq): bool =
  cmp(a, b) == 0

