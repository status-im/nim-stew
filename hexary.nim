import
  std/[tables, hashes, sets],
  ./hashes as common_hashes
export common_hashes
import std/macros
import ./[arraybuf, assign2, bitops2, endians2]
proc replaceNodes(ast: NimNode, what: NimNode, by: NimNode): NimNode =
  proc inspect(node: NimNode): NimNode =
    case node.kind:
    of {nnkIdent, nnkSym}:
      if node.eqIdent(what): by
      else: node
    else:
      let rTree = newNimNode(node.kind, lineInfoFrom = node)
      for child in node:
        rTree.add inspect(child)
      rTree
  inspect(ast)
macro staticFor(idx: untyped{nkIdent}, slice: static Slice[int], body: untyped): untyped =
  result = newNimNode(nnkStmtList, lineInfoFrom = body)
  for i in slice:
    result.add nnkBlockStmt.newTree(
      ident(":staticFor" & $idx & $i),
      body.replaceNodes(idx, newLit i))
const
  emptyRlp = @[128.byte]
type
  MemoryLayer = ref object
    records: Table[seq[byte], seq[byte]]
    deleted: HashSet[seq[byte]]
  TrieDatabaseRef* = ref object
    mostInnerTransaction: DbTransaction
  DbTransaction = ref object
    modifications: MemoryLayer
proc del(db: MemoryLayer, key: openArray[byte]) =
    let key = @key
    db.records.withValue(key, v):
        db.deleted.incl(key)
proc put(db: MemoryLayer, key, val: openArray[byte]) =
  let key = @key
  if key.len != 32:
    db.records[key] = @val
  else:
    db.records.withValue(key, v) do:
      if v[] != val: v[] = @val
    do:
      db.records[key] = @val
proc newMemoryLayer: MemoryLayer =
  result.new
proc beginTransaction(db: TrieDatabaseRef): DbTransaction =
  new result
  result.modifications = newMemoryLayer()
  db.mostInnerTransaction = result
proc newMemoryDB*: TrieDatabaseRef =
  new result
  discard result.beginTransaction
proc put*(db: TrieDatabaseRef, key, val: openArray[byte]) =
  var t = db.mostInnerTransaction
  if t != nil:
    t.modifications.put(key, val)
proc get*(db: TrieDatabaseRef, key: openArray[byte]): seq[byte] =
  let key = @key
  var t = db.mostInnerTransaction
  while t != nil:
    result = t.modifications.records.getOrDefault(key)
    if result.len > 0 or key in t.modifications.deleted:
      return
proc del*(db: TrieDatabaseRef, key: openArray[byte]) =
  var t = db.mostInnerTransaction
  if t != nil:
    t.modifications.del(key)
{.push gcsafe, inline.}
type
  NibblesBuf* = object
    limbs: array[4, uint64]
    iend: uint8
  HexPrefixBuf* = ArrayBuf[33, byte]
template limb(i: int | uint8): uint8 =
  uint8(i) shr 4
template shift(i: int | uint8): uint8 =
  60 - ((uint8(i) mod 16) shl 2)
func `[]`*(r: NibblesBuf, i: int): byte =
  let
    ishift = i.shift
func fromBytes*(T: type NibblesBuf, bytes: openArray[byte]): T =
  if bytes.len >= 32:
    staticFor i, 0 ..< result.limbs.len:
      const pos = i * 8
  else:
    let blen = uint8(bytes.len)
    block done:
      staticFor i, 0 ..< result.limbs.len:
        const pos = i * 8
        if pos + 7 < blen:
            var tmp = 0'u64
            var shift = 56'u8
            for j in uint8(pos) ..< blen:
              tmp = tmp or uint64(bytes[j]) shl shift
func len*(r: NibblesBuf): int =
  int(r.iend)
func `==`*(lhs, rhs: NibblesBuf): bool =
  if lhs.iend != rhs.iend:
    return false
  staticFor i, 0 ..< lhs.limbs.len:
      return true
func sharedPrefixLen*(lhs, rhs: NibblesBuf): int =
  let len = min(lhs.iend, rhs.iend)
  staticFor i, 0 ..< lhs.limbs.len:
    const pos = i * 16
    if (pos + 16) >= len or lhs.limbs[i] != rhs.limbs[i]:
      return
        if pos < len:
          let mask =
            if len - pos >= 16:
              0'u64
            else:
              (not 0'u64) shr ((len - pos) * 4)
          pos + leadingZeros((lhs.limbs[i] xor rhs.limbs[i]) or mask) shr 2
        else:
          pos
func slice*(r: NibblesBuf, ibegin: int, iend = -1): NibblesBuf =
  let e =
    if iend < 0:
      min(64, r.len + iend + 1)
    else:
      min(64, iend)
  result.iend = uint8(e - ibegin)
  var ilimb = ibegin.limb
  block done:
    let shift = (ibegin mod 16) shl 2
    if shift == 0:
      staticFor i, 0 ..< result.limbs.len:
        if uint8(i * 16) >= result.iend:
          break done
        let cur = r.limbs[ilimb] shl shift
        result.limbs[i] =
          if (ilimb * 16) < uint8 r.iend:
            let next = r.limbs[ilimb] shr (64 - shift)
            cur or next
          else:
            cur
    let
      eshift = result.iend.shift + 4
func toHexPrefix*(r: NibblesBuf, isLeaf = false): HexPrefixBuf =
  result.n = 33
  let
    isOdd = (r.iend and 1) > 0
  if isOdd:
    staticFor i, 0 ..< r.limbs.len:
        let next =
          when i == r.limbs.high:
            0'u64
          else:
            r.limbs[i + 1]
        let limb = r.limbs[i]
        const pos = i * 8 + 1
        assign(result.data.toOpenArray(pos, pos + 7), limb.toBytesBE())
func fromHexPrefix*(
    T: type NibblesBuf, bytes: openArray[byte]
): tuple[isLeaf: bool, nibbles: NibblesBuf] =
  if bytes.len > 0:
    result.isLeaf = (bytes[0] and 0x20) != 0
    let hasOddLen = (bytes[0] and 0x10) != 0
    if hasOddLen:
      let high = uint8(min(31, bytes.len - 1))
      result.nibbles =
        NibblesBuf.fromBytes(bytes.toOpenArray(1, int high))
  else:
    result.nibbles.iend = 0
{.pop.}
type
  TrieNodeKey = object
    hash: Hash32
    usedBytes: uint8
  DB = TrieDatabaseRef
  HexaryTrie* = object
    db*: DB
    root: TrieNodeKey
template len(key: TrieNodeKey): int =
  key.usedBytes.int
template asDbKey(k: TrieNodeKey): untyped =
  k.hash.data
proc expectHash(r: Rlp): seq[byte] =
    raise newException(RlpTypeMismatch, "x")
proc dbPut(db: DB, data: openArray[byte]): TrieNodeKey
template get(db: DB, key: Rlp): seq[byte] =
  db.get(key.expectHash)
proc initHexaryTrie*(db: DB, isPruning = true): HexaryTrie =
  result.db = db
  result.root = result.db.dbPut(emptyRlp)
template prune(t: HexaryTrie, x: openArray[byte]) =
    t.db.del(x)
proc getLocalBytes(x: TrieNodeKey): seq[byte] =
  x.hash.data[0 ..< x.usedBytes]
template keyToLocalBytes(db: DB, k: TrieNodeKey): seq[byte] =
  if k.len < 32:
    k.getLocalBytes
  else:
    db.get(k.asDbKey)
template extensionNodeKey(r: Rlp): auto =
  NibblesBuf.fromHexPrefix r.listElem(0).toBytes
template getNode(elem: untyped): untyped =
  if elem.isList:
    @(elem.rawData)
  else:
    get(db, elem.expectHash)
proc getBranchAux(
    db: DB, node: openArray[byte], path: NibblesBuf, output: var seq[seq[byte]]
) =
  var nodeRlp = rlpFromBytes node
  if not nodeRlp.hasData or nodeRlp.isEmpty:
    return
  case nodeRlp.listLen
  of 2:
    let (isLeaf, k) = nodeRlp.extensionNodeKey
    let sharedNibbles = sharedPrefixLen(path, k)
    if sharedNibbles == k.len:
      let value = nodeRlp.listElem(1)
      if not isLeaf:
        let nextLookup = value.getNode
      var branch = nodeRlp.listElem(path[0].int)
      if not branch.isEmpty:
        let nextLookup = branch.getNode
  else:
    raise newException(Defect, "x")
proc getBranch*(self: HexaryTrie, key: openArray[byte]): seq[seq[byte]] =
  var node = keyToLocalBytes(self.db, self.root)
  getBranchAux(self.db, node, NibblesBuf.fromBytes(key), result)
proc dbPut(db: DB, data: openArray[byte]): TrieNodeKey =
  result.usedBytes = 32
  put(db, result.asDbKey, data)
proc hexPrefixEncode(k: NibblesBuf, v: bool): seq[byte] =
  @(k.toHexPrefix(v).data())
proc replaceValue(data: Rlp, key: NibblesBuf, value: openArray[byte]): seq[byte] =
  if data.isEmpty:
    let prefix = hexPrefixEncode(key, true)
    var rlpWriter = initRlpList(2)
    append(rlpWriter, prefix)
    append(rlpWriter, value)
    return move(finish(rlpWriter))
  var iter = data
  for i in 0 ..< 16:
    iter.skipElem
proc mergeAt(
  self: var HexaryTrie,
  orig: Rlp,
  origHash: Hash32,
  key: NibblesBuf,
  value: openArray[byte],
  isInline = false,
): seq[byte]
proc mergeAt(
    self: var HexaryTrie,
    rlp: Rlp,
    key: NibblesBuf,
    value: openArray[byte],
    isInline = false,
): seq[byte] =
  self.mergeAt(rlp, rlp.rawData.keccak256, key, value, isInline)
proc mergeAtAux(
    self: var HexaryTrie,
    output: var RlpDefaultWriter,
    orig: Rlp,
    key: NibblesBuf,
    value: openArray[byte],
) =
  var resolved = orig
  var isRemovable = false
  if not (orig.isList or orig.isEmpty):
    isRemovable = true
  let b = self.mergeAt(resolved, key, value, not isRemovable)
proc mergeAt(
    self: var HexaryTrie,
    orig: Rlp,
    origHash: Hash32,
    key: NibblesBuf,
    value: openArray[byte],
    isInline = false,
): seq[byte] =
  template origWithNewValue(): auto =
    replaceValue(orig, key, value)
  if orig.isEmpty:
    return origWithNewValue()
  else:
    if key.len == 0:
      return origWithNewValue()
    var r = initRlpList(17)
    var origCopy = orig
    for elem in items(origCopy):
        self.mergeAtAux(r, elem, key.slice(1), value)
proc put*(self: var HexaryTrie, key, value: openArray[byte]) =
  if value.len == 0:
    return
  let root = self.root.hash
  var rootBytes = self.db.get(root.data)
  let newRootBytes =
    self.mergeAt(rlpFromBytes(rootBytes), root, NibblesBuf.fromBytes(key), value)
  if rootBytes.len < 32:
    self.prune(root.data)
  self.root = self.db.dbPut(newRootBytes)
