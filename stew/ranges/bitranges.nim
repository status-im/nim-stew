import
  typedranges, ptr_arith

type
  BitRange* = object
    data: MutByteRange
    start: int
    mLen: int

  BitIndexable = SomeUnsignedInt

template `@`(s, idx: untyped): untyped =
  (when idx is BackwardsIndex: s.len - int(idx) else: int(idx))

proc bits*(a: MutByteRange, start, len: int): BitRange =
  doAssert start <= len
  doAssert len <= 8 * a.len
  result.data = a
  result.start = start
  result.mLen = len

template bits*(a: var seq[byte], start, len: int): BitRange =
  bits(a.toRange, start, len)

template bits*(a: MutByteRange): BitRange =
  bits(a, 0, a.len * 8)

template bits*(a: var seq[byte]): BitRange =
  bits(a.toRange, 0, a.len * 8)

template bits*(a: MutByteRange, len: int): BitRange =
  bits(a, 0, len)

template bits*(a: var seq[byte], len: int): BitRange =
  bits(a.toRange, 0, len)

template bits*(bytes: MutByteRange, slice: HSlice): BitRange =
  bits(bytes, bytes @ slice.a, bytes @ slice.b)

template bits*(x: BitRange): BitRange = x

template mostSignificantBit(T: typedesc): auto =
  const res = 1 shl (sizeof(T) * 8 - 1)
  T(res)

template getBit*(x: BitIndexable, bit: Natural): bool =
  ## reads a bit from `x`, assuming 0 to be the position of the
  ## most significant bit
  (x and mostSignificantBit(x.type) shr bit) != 0

template getBitLE*(x: BitIndexable, bit: Natural): bool =
  ## reads a bit from `x`, assuming 0 to be the position of the
  ## least significant bit
  type T = type(x)
  (x and T(0b1 shl bit)) != 0

proc setBit*(x: var BitIndexable, bit: Natural, val: bool) =
  ## writes a bit in `x`, assuming 0 to be the position of the
  ## most significant bit
  let mask = mostSignificantBit(x.type) shr bit
  if val:
    x = x or mask
  else:
    x = x and not mask

proc setBitLE*(x: var BitIndexable, bit: Natural, val: bool) =
  ## writes a bit in `x`, assuming 0 to be the position of the
  ## least significant bit
  type T = type(x)
  let mask = 0b1 shl bit
  if val:
    x = x or mask
  else:
    x = x and not mask

proc raiseBit*(x: var BitIndexable, bit: Natural) =
  ## raises a bit in `x`, assuming 0 to be the position of the
  ## most significant bit
  type T = type(x)
  let mask = mostSignificantBit(x.type) shr bit
  x = x or mask

proc lowerBit*(x: var BitIndexable, bit: Natural) =
  ## raises a bit in `x`, assuming 0 to be the position of the
  ## most significant bit
  type T = type(x)
  let mask = mostSignificantBit(x.type) shr bit
  x = x and not mask

proc raiseBitLE*(x: var BitIndexable, bit: Natural) =
  ## raises bit in `x`, assuming 0 to be the position of the
  ## least significant bit
  type T = type(x)
  let mask = 0b1 shl bit
  x = x or mask

proc lowerBitLE*(x: var BitIndexable, bit: Natural) =
  ## raises bit in a byte, assuming 0 to be the position of the
  ## least significant bit
  type T = type(x)
  let mask = 0b1 shl bit
  x = x and not mask

proc len*(r: BitRange): int {.inline.} = r.mLen

template getAbsoluteBit(bytes, absIdx: untyped): bool =
  ## Returns a bit with a position relative to the start of
  ## the underlying range. Not to be confused with a position
  ## relative to the start of the BitRange (i.e. the two would
  ## match only when range.start == 0).
  let
    byteToCheck = absIdx shr 3 # the same as absIdx / 8
    bitToCheck  = (absIdx and 0b111)

  getBit(bytes[byteToCheck], bitToCheck)

template setAbsoluteBit(bytes, absIdx, value) =
  let
    byteToWrite = absIdx shr 3 # the same as absIdx / 8
    bitToWrite  = (absIdx and 0b111)

  setBit(bytes[byteToWrite], bitToWrite, value)

iterator enumerateBits(x: BitRange): (int, bool) =
  var p = x.start
  var i = 0
  let e = x.len
  while i != e:
    yield (i, getAbsoluteBit(x.data, p))
    inc p
    inc i

proc getBit*(bytes: openarray[byte], pos: Natural): bool =
  getAbsoluteBit(bytes, pos)

proc setBit*(bytes: var openarray[byte], pos: Natural, value: bool) =
  setAbsoluteBit(bytes, pos, value)

iterator items*(x: BitRange): bool =
  for _, v in enumerateBits(x): yield v

iterator pairs*(x: BitRange): (int, bool) =
  for i, v in enumerateBits(x): yield (i, v)

proc `[]`*(x: BitRange, idx: int): bool {.inline.} =
  doAssert idx < x.len
  let p = x.start + idx
  result = getAbsoluteBit(x.data, p)

proc sliceNormalized(x: BitRange, ibegin, iend: int): BitRange =
  doAssert ibegin >= 0 and
         ibegin < x.len and
         iend < x.len and
         iend + 1 >= ibegin # the +1 here allows the result to be
                            # an empty range

  result.data  = x.data
  result.start = x.start + ibegin
  result.mLen  = iend - ibegin + 1

proc `[]`*(r: BitRange, s: HSlice): BitRange {.inline.} =
  sliceNormalized(r, r @ s.a, r @ s.b)

proc `==`*(a, b: BitRange): bool =
  if a.len != b.len: return false
  for i in 0 ..< a.len:
    if a[i] != b[i]: return false
  true

proc `[]=`*(r: var BitRange, idx: Natural, val: bool) {.inline.} =
  doAssert idx < r.len
  let absIdx = r.start + idx
  setAbsoluteBit(r.data, absIdx, val)

proc setAbsoluteBit(x: BitRange, absIdx: int, val: bool) {.inline.} =
  ## Assumes the destination bit is already zeroed.
  ## Works with absolute positions similar to `getAbsoluteBit`
  doAssert absIdx < x.len
  let
    byteToWrite = absIdx shr 3 # the same as absIdx / 8
    bitToWrite  = (absIdx and 0b111)

  if val:
    raiseBit x.data[byteToWrite], bitToWrite

proc pushFront*(x: var BitRange, val: bool) =
  doAssert x.start > 0
  dec x.start
  x[0] = val
  inc x.mLen

template neededBytes(nBits: int): int =
  (nBits shr 3) + ord((nBits and 0b111) != 0)

static:
  doAssert neededBytes(2) == 1
  doAssert neededBytes(8) == 1
  doAssert neededBytes(9) == 2

proc `&`*(a, b: BitRange): BitRange =
  let totalLen = a.len + b.len

  var bytes = newSeq[byte](totalLen.neededBytes)
  result = bits(bytes, 0, totalLen)

  for i in 0 ..< a.len: result.setAbsoluteBit(i, a[i])
  for i in 0 ..< b.len: result.setAbsoluteBit(i + a.len, b[i])

proc `$`*(r: BitRange): string =
  result = newStringOfCap(r.len)
  for b in r:
    result.add(if b: '1' else: '0')

proc fromBits*(T: typedesc, r: BitRange, offset, num: Natural): T =
  doAssert(num <= sizeof(T) * 8)
  # XXX: Nim has a bug that a typedesc parameter cannot be used
  # in a type coercion, so we must define an alias here:
  type TT = T
  for i in 0 ..< num:
    result = (result shl 1) or TT(r[offset + i])

proc parse*(T: typedesc[BitRange], s: string): BitRange =
  var bytes = newSeq[byte](s.len.neededBytes)
  for i, c in s:
    case c
    of '0': discard
    of '1': raiseBit(bytes[i shr 3], i and 0b111)
    else: doAssert false
  result = bits(bytes, 0, s.len)

