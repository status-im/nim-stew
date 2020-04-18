{.deprecated: "unattractive memory unsafety - use openArray and other techniques instead".}

import ../ptrops, typetraits, hashes

const rangesGCHoldEnabled = not defined(rangesDisableGCHold)
const unsafeAPIEnabled* = defined(rangesEnableUnsafeAPI)

type
  # A view into immutable array
  Range*[T] {.shallow.} = object
    when rangesGCHoldEnabled:
      gcHold: seq[T]
    start: ptr T
    mLen: int

  # A view into mutable array
  MutRange*[T] {.shallow.} = distinct Range[T]

  ByteRange* = Range[byte]
  MutByteRange* = MutRange[byte]

proc isLiteral[T](s: seq[T]): bool {.inline.} =
  type
    SeqHeader = object
      length, reserved: int
  (cast[ptr SeqHeader](s).reserved and (1 shl (sizeof(int) * 8 - 2))) != 0

proc toImmutableRange[T](a: seq[T]): Range[T] =
  if a.len != 0:
    when rangesGCHoldEnabled:
      if not isLiteral(a):
        shallowCopy(result.gcHold, a)
      else:
        result.gcHold = a
    result.start = addr result.gcHold[0]
    result.mLen = a.len

when unsafeAPIEnabled:
  proc toImmutableRangeNoGCHold[T](a: openarray[T]): Range[T] =
    if a.len != 0:
      result.start = unsafeAddr a[0]
      result.mLen = a.len

  proc toImmutableRange[T](a: openarray[T]): Range[T] {.inline.} =
    toImmutableRangeNoGCHold(a)

proc toRange*[T](a: var seq[T]): MutRange[T] {.inline.} =
  MutRange[T](toImmutableRange(a))

when unsafeAPIEnabled:
  proc toRange*[T](a: var openarray[T]): MutRange[T] {.inline.} =
    MutRange[T](toImmutableRange(a))

  template initStackRange*[T](sz: static[int]): MutRange[T] =
    var data: array[sz, T]
    data.toRange()

  proc toRange*[T](a: openarray[T]): Range[T] {.inline.} = toImmutableRange(a)

  proc unsafeRangeConstruction*[T](a: var openarray[T]): MutRange[T] {.inline.} =
    MutRange[T](toImmutableRange(a))

  proc unsafeRangeConstruction*[T](a: openarray[T]): Range[T] {.inline.} =
    toImmutableRange(a)

proc newRange*[T](sz: int): MutRange[T] {.inline.} =
  MutRange[T](toImmutableRange(newSeq[T](sz)))

proc toRange*[T](a: seq[T]): Range[T] {.inline.} = toImmutableRange(a)

converter toImmutableRange*[T](a: MutRange[T]): Range[T] {.inline.} = Range[T](a)

proc len*(r: Range): int {.inline.} = int(r.mLen)

proc high*(r: Range): int {.inline.} = r.len - 1
proc low*(r: Range): int {.inline.} = 0

proc elemAt[T](r: MutRange[T], idx: int): var T {.inline.} =
  doAssert(idx < r.len)
  Range[T](r).start.offset(idx)[]

proc `[]=`*[T](r: MutRange[T], idx: int, v: T) {.inline.} = r.elemAt(idx) = v
proc `[]`*[T](r: MutRange[T], i: int): var T = r.elemAt(i)

proc `[]`*[T](r: Range[T], idx: int): T {.inline.} =
  doAssert(idx < r.len)
  r.start.offset(idx)[]

proc `==`*[T](a, b: Range[T]): bool =
  if a.len != b.len: return false
  equalMem(a.start, b.start, sizeof(T) * a.len)

iterator ptrs[T](r: Range[T]): (int, ptr T) =
  var p = r.start
  var i = 0
  let e = r.len
  while i != e:
    yield (i, p)
    p = p.offset(1)
    inc i

iterator items*[T](r: Range[T]): T =
  for _, v in ptrs(r): yield v[]

iterator pairs*[T](r: Range[T]): (int, T) =
  for i, v in ptrs(r): yield (i, v[])

iterator mitems*[T](r: MutRange[T]): var T =
  for _, v in ptrs(r): yield v[]

iterator mpairs*[T](r: MutRange[T]): (int, var T) =
  for i, v in ptrs(r): yield (i, v[])

proc toSeq*[T](r: Range[T]): seq[T] =
  result = newSeqOfCap[T](r.len)
  for i in r: result.add(i)

proc `$`*(r: Range): string =
  result = "R["
  for i, v in r:
    if i != 0:
      result &= ", "
    result &= $v
  result &= "]"

proc sliceNormalized[T](r: Range[T], ibegin, iend: int): Range[T] =
  doAssert ibegin >= 0 and
         ibegin < r.len and
         iend < r.len and
         iend + 1 >= ibegin # the +1 here allows the result to be
                            # an empty range

  when rangesGCHoldEnabled:
    shallowCopy(result.gcHold, r.gcHold)
  result.start = r.start.offset(ibegin)
  result.mLen = iend - ibegin + 1

proc slice*[T](r: Range[T], ibegin = 0, iend = -1): Range[T] =
  let e = if iend < 0: r.len + iend
          else: iend
  sliceNormalized(r, ibegin, e)

proc slice*[T](r: MutRange[T], ibegin = 0, iend = -1): MutRange[T] {.inline.} =
  MutRange[T](Range[T](r).slice(ibegin, iend))

template `^^`(s, i: untyped): untyped =
  (when i is BackwardsIndex: s.len - int(i) else: int(i))

proc `[]`*[T, U, V](r: Range[T], s: HSlice[U, V]): Range[T] {.inline.} =
  sliceNormalized(r, r ^^ s.a, r ^^ s.b)

proc `[]`*[T, U, V](r: MutRange[T], s: HSlice[U, V]): MutRange[T] {.inline.} =
  MutRange[T](sliceNormalized(r, r ^^ s.a, r ^^ s.b))

proc `[]=`*[T, U, V](r: MutRange[T], s: HSlice[U, V], v: openarray[T]) =
  let a = r ^^ s.a
  let b = r ^^ s.b
  let L = b - a + 1
  if L == v.len:
    for i in 0..<L: r[i + a] = v[i]
  else:
    raise newException(RangeError, "different lengths for slice assignment")

template toOpenArray*[T](r: Range[T]): auto =
  when false:
  # when (NimMajor,NimMinor,NimPatch)>=(0,19,9):
    # error message in Nim HEAD 2019-01-02:
    # "for a 'var' type a variable needs to be passed, but 'toOpenArray(cast[ptr UncheckedArray[T]](curHash.start), 0, high(curHash))' is immutable"
    toOpenArray(cast[ptr UncheckedArray[T]](r.start), 0, r.high)
  else:
    # NOTE: `0` in `array[0, T]` is irrelevant
    toOpenArray(cast[ptr array[0, T]](r.start)[], 0, r.high)

proc `[]=`*[T, U, V](r: MutRange[T], s: HSlice[U, V], v: Range[T]) {.inline.} =
  r[s] = toOpenArray(v)

proc baseAddr*[T](r: Range[T]): ptr T {.inline.} = r.start
proc gcHolder*[T](r: Range[T]): ptr T {.inline.} =
  ## This procedure is used only for shallow test, do not use it
  ## in production.
  when rangesGCHoldEnabled:
    if r.len > 0:
      result = unsafeAddr r.gcHold[0]
template toRange*[T](a: Range[T]): Range[T] = a

# this preferred syntax doesn't work
# see https://github.com/nim-lang/Nim/issues/7995
#template copyRange[T](dest: seq[T], destOffset: int, src: Range[T]) =
#  when supportsCopyMem(T):

template copyRange[T](E: typedesc, dest: seq[T], destOffset: int, src: Range[T]) =
  when supportsCopyMem(E):
    if dest.len != 0 and src.len != 0:
      copyMem(dest[destOffset].unsafeAddr, src.start, sizeof(T) * src.len)
  else:
    for i in 0..<src.len:
      dest[i + destOffset] = src[i]

proc concat*[T](v: varargs[Range[T], toRange]): seq[T] =
  var len = 0
  for c in v: inc(len, c.len)
  result = newSeq[T](len)
  len = 0
  for c in v:
    copyRange(T, result, len, c)
    inc(len, c.len)

proc `&`*[T](a, b: Range[T]): seq[T] =
  result = newSeq[T](a.len + b.len)
  copyRange(T, result, 0, a)
  copyRange(T, result, a.len, b)

proc hash*(x: Range): Hash =
  result = hash(toOpenArray(x))

template advanceImpl(a, b: untyped): bool =
  var res = false
  if b == 0:
    res = true
  elif b > 0:
    if isNil(a.start) or a.mLen <= 0:
      res = false
    else:
      if a.mLen - b < 0:
        res = false
      else:
        a.start = a.start.offset(b)
        a.mLen -= b
        res = true
  res

proc tryAdvance*[T](x: var Range[T], idx: int): bool =
  ## Move internal start offset of range ``x`` by ``idx`` elements forward.
  ##
  ## Returns ``true`` if operation got completed successfully, or
  ## ``false`` if you are trying to overrun range ``x``.
  result = x.advanceImpl(idx)

proc tryAdvance*[T](x: var MutRange[T], idx: int): bool {.inline.} =
  ## Move internal start offset of range ``x`` by ``idx`` elements forward.
  ##
  ## Returns ``true`` if operation got completed successfully, or
  ## ``false`` if you are trying to overrun range ``x``.
  result = tryAdvance(Range[T](x), idx)

proc advance*[T](x: var Range[T], idx: int) =
  ## Move internal start offset of range ``x`` by ``idx`` elements forward.
  let res = x.advanceImpl(idx)
  if not res: raise newException(IndexError, "Advance Error")

proc advance*[T](x: var MutRange[T], idx: int) {.inline.} =
  ## Move internal start offset of range ``x`` by ``idx`` elements forward.
  advance(Range[T](x), idx)
