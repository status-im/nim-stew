import
  ../bitops2, typedranges

type
  BitRange* = object
    data: MutByteRange
    start: int
    mLen: int

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

proc len*(r: BitRange): int {.inline.} = r.mLen

iterator enumerateBits(x: BitRange): (int, bool) =
  var p = x.start
  var i = 0
  let e = x.len
  while i != e:
    yield (i, getBitBE(x.data.toOpenArray, p))
    inc p
    inc i

iterator items*(x: BitRange): bool =
  for _, v in enumerateBits(x): yield v

iterator pairs*(x: BitRange): (int, bool) =
  for i, v in enumerateBits(x): yield (i, v)

proc `[]`*(x: BitRange, idx: int): bool {.inline.} =
  doAssert idx < x.len
  let p = x.start + idx
  result = getBitBE(x.data.toOpenArray, p)

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
  changeBitBE(r.data.toOpenArray, absIdx, val)

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

  for i in 0 ..< a.len: result.data.toOpenArray.changeBitBE(i, a[i])
  for i in 0 ..< b.len: result.data.toOpenArray.changeBitBE(i + a.len, b[i])

proc `$`*(r: BitRange): string =
  result = newStringOfCap(r.len)
  for bit in r:
    result.add(if bit: '1' else: '0')

proc fromBits*(T: type, r: BitRange, offset, num: Natural): T =
  doAssert(num <= sizeof(T) * 8)
  # XXX: Nim has a bug that a typedesc parameter cannot be used
  # in a type coercion, so we must define an alias here:
  type TT = T
  for i in 0 ..< num:
    result = (result shl 1) or TT(r[offset + i])

proc parse*(T: type BitRange, s: string): BitRange =
  var bytes = newSeq[byte](s.len.neededBytes)
  for i, c in s:
    case c
    of '0': discard
    of '1': setBitBE(bytes, i)
    else: doAssert false
  result = bits(bytes, 0, s.len)

