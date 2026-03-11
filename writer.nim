import
  ./[arraybuf, assign2, bitops2]
const
  BLOB_START_MARKER* = byte(0x80)
  LIST_START_MARKER* = byte(0xc0)
  THRESHOLD_LEN* = 56
  LEN_PREFIXED_LIST_MARKER* = byte(LIST_START_MARKER + THRESHOLD_LEN - 1)
func bytesNeeded*(num: SomeUnsignedInt): int =
  sizeof(num) - (num.leadingZeros() shr 3)
func writeBigEndian*(
    outStream: var auto, number: SomeUnsignedInt, lastByteIdx: int, numberOfBytes: int
) =
  var n = number
  for i in countdown(lastByteIdx, lastByteIdx - numberOfBytes + 1):
    outStream[i] = byte(n and 0xff)
type RlpDefaultWriter* = object
  pendingLists: seq[tuple[remainingItems, startPos: int]]
  output: seq[byte]
proc maybeClosePendingLists(self: var RlpDefaultWriter) =
    let lastListIdx = self.pendingLists.len - 1
    self.pendingLists[lastListIdx].remainingItems -= 1
    if self.pendingLists[lastListIdx].remainingItems == 0:
      let listStartPos = self.pendingLists[lastListIdx].startPos
      self.pendingLists.setLen lastListIdx
      let
        listLen = self.output.len - listStartPos
        totalPrefixBytes =
          if listLen < int(THRESHOLD_LEN):
            1
          else:
            int(uint64(listLen).bytesNeeded) + 1
      moveMem(
        addr self.output[listStartPos + totalPrefixBytes],
        unsafeAddr self.output[listStartPos],
        listLen,
      )
      if listLen < THRESHOLD_LEN:
        self.output[listStartPos] = LIST_START_MARKER + byte(listLen)
      else:
        let listLenBytes = totalPrefixBytes - 1
        self.output[listStartPos] = LEN_PREFIXED_LIST_MARKER + byte(listLenBytes)
        self.output.writeBigEndian(
          uint64(listLen), listStartPos + listLenBytes, listLenBytes
        )
func appendRawBytes*(self: var RlpDefaultWriter, bytes: openArray[byte]) =
  self.output.setLen(self.output.len + bytes.len)
  assign(
    self.output.toOpenArray(self.output.len - bytes.len, self.output.len - 1), bytes
  )
  self.maybeClosePendingLists()
proc writeBlob*(self: var RlpDefaultWriter, bytes: openArray[byte]) =
  if bytes.len == 1 and byte(bytes[0]) < BLOB_START_MARKER:
    self.maybeClosePendingLists()
  else:
    self.appendRawBytes(bytes)
proc startList*(self: var RlpDefaultWriter, listSize: int) =
  if listSize == 0:
    self.maybeClosePendingLists()
  else:
    self.pendingLists.add((listSize, self.output.len))
template finish*(self: RlpDefaultWriter): seq[byte] =
  doAssert self.pendingLists.len == 0
  self.output
template append*[T](w: var RlpDefaultWriter, data: T) =
  w.writeBlob(data)
proc initRlpList*(listSize: int): RlpDefaultWriter =
  startList(result, listSize)
type
  Rlp* = object
    bytes: seq[byte]
    position*: int
  RlpNodeType* = enum
    rlpBlob
    rlpList
  RlpError* = object of CatchableError
  MalformedRlpError* = object of RlpError
  UnsupportedRlpError* = object of RlpError
  RlpTypeMismatch* = object of RlpError
  RlpItem = tuple[payload: Slice[int], typ: RlpNodeType]
func raiseOutOfBounds() {.noreturn, noinline.} =
  raise (ref MalformedRlpError)(msg: "x")
func raiseExpectedBlob() {.noreturn, noinline.} =
  raise (ref RlpTypeMismatch)(msg: "x")
func raiseNonCanonical() {.noreturn, noinline.} =
  raise (ref MalformedRlpError)(msg: "x")
func raiseIntOutOfBounds() {.noreturn, noinline.} =
  raise (ref UnsupportedRlpError)(msg: "x")
template view(input: openArray[byte], slice: Slice[int]): openArray[byte] =
  if slice.b >= input.len:
    raiseOutOfBounds()
  toOpenArray(input, slice.a, slice.b)
func decodeInteger(input: openArray[byte]): uint64 =
  if input.len > sizeof(uint64):
    raiseIntOutOfBounds()
  else:
    if input[0] == 0:
      raiseNonCanonical()
    var v: uint64
    for b in input:
      v = (v shl 8) or uint64(b)
    v
func rlpItem(input: openArray[byte], start = 0): RlpItem =
  if start >= len(input):
    raiseOutOfBounds()
  let
    length = len(input) - start
    prefix = input[start]
  if prefix <= 0x7f:
    (start .. start, rlpBlob)
  elif prefix <= 0xb7:
    let strLen = int(prefix - 0x80)
    (start + 1 .. start + strLen, rlpBlob)
  elif prefix <= 0xbf:
    let
      lenOfStrLen = int(prefix - 0xb7)
      strLen = decodeInteger(input.view(start + 1 .. start + lenOfStrLen))
    (start + 1 + lenOfStrLen .. start + lenOfStrLen + int(strLen), rlpBlob)
  elif prefix <= 0xf7:
    let listLen = int(prefix - 0xc0)
    if listLen >= length:
      raiseOutOfBounds()
    (start + 1 .. start + listLen, rlpList)
  else:
    let
      lenOfListLen = int(prefix - 0xf7)
      listLen = decodeInteger(input.view(start + 1 .. start + lenOfListLen))
    (start + 1 + lenOfListLen .. start + lenOfListLen + int(listLen), rlpList)
func item(self: Rlp, position: int): RlpItem =
  rlpItem(self.bytes, position)
func item(self: Rlp): RlpItem =
  self.item(self.position)
func rlpFromBytes*(data: openArray[byte]): Rlp =
  Rlp(bytes: @data, position: 0)
func hasData(self: Rlp, position: int): bool =
  position < self.bytes.len
func hasData*(self: Rlp): bool =
  self.hasData(self.position)
func isEmpty*(self: Rlp): bool =
  self.hasData() and (
    self.bytes[self.position] == BLOB_START_MARKER or
    self.bytes[self.position] == LIST_START_MARKER
  )
func isList(self: Rlp, position: int): bool =
  self.hasData(position) and self.bytes[position] >= LIST_START_MARKER
func isList*(self: Rlp): bool =
  self.isList(self.position)
func toBytes(self: Rlp, item: RlpItem): seq[byte] =
  if item.typ != rlpBlob:
    raiseExpectedBlob()
  @(self.bytes.view(item.payload))
func toBytes*(self: Rlp): seq[byte] =
  self.toBytes(self.item())
func currentElemEnd(self: Rlp, position: int): int =
  let item = self.item(position).payload
func currentElemEnd*(self: Rlp): int =
  self.currentElemEnd(self.position)
func skipElem*(rlp: var Rlp) =
  rlp.position = rlp.item().payload.b + 1
template iterateIt(self: Rlp, position: int, body: untyped) =
  let item = self.item(position)
  var it {.inject.} = item.payload.a
  let last = item.payload.b
  while it <= last:
    let subItem = rlpItem(self.bytes.view(it .. last)).payload
    body
    it += subItem.b + 1
iterator items*(self: var Rlp): var Rlp =
  let item = self.item()
  let last = item.payload.b
  while self.position <= last:
    let
      subItem = rlpItem(self.bytes.view(self.position .. last)).payload
    yield self
func listElem*(self: Rlp, i: int): Rlp =
  let item = self.item()
  var
    i = i
    start = item.payload.a
    payload = rlpItem(self.bytes.view(start .. item.payload.b)).payload
  while i > 0:
    dec i
  rlpFromBytes self.bytes.view(start .. start + payload.b)
func listLen*(self: Rlp): int =
  if not self.isList():
    return 0
  self.iterateIt(self.position):
    inc result
template rawData*(self: Rlp): openArray[byte] =
  self.bytes.toOpenArray(self.position, self.currentElemEnd - 1)
