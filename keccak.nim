template ROL(x: uint64, n: int): uint64 =
  (x shl uint64(n and 0x3F)) or (x shr uint64(64 - (n and 0x3F)))

template leLoad64(src: openArray[byte], srco: int): uint64 =
  var p: uint64
  copyMem(addr p, unsafeAddr src[srco], sizeof(uint64))
  p

template leStore64(dst: var openArray[byte], so: int, v: uint64) =
  copyMem(addr dst[so], unsafeAddr v, sizeof(uint64))

type
  MDigest*[bits: static[int]] = object
    data*: array[bits div 8, byte]

const RNDC = [
  0x0000000000000001'u64, 0x0000000000008082'u64, 0x800000000000808A'u64,
  0x8000000080008000'u64, 0x000000000000808B'u64, 0x0000000080000001'u64,
  0x8000000080008081'u64, 0x8000000000008009'u64, 0x000000000000008A'u64,
  0x0000000000000088'u64, 0x0000000080008009'u64, 0x000000008000000A'u64,
  0x000000008000808B'u64, 0x800000000000008B'u64, 0x8000000000008089'u64,
  0x8000000000008003'u64, 0x8000000000008002'u64, 0x8000000000000080'u64,
  0x000000000000800A'u64, 0x800000008000000A'u64, 0x8000000080008081'u64,
  0x8000000000008080'u64, 0x0000000080000001'u64, 0x8000000080008008'u64
]

type
  KeccakContext*[bits: static[int]] = object
    q: array[25 * 8, byte]
    pt: int

template THETA1(a, b, c: untyped) =
  a[c] = b[c] xor b[c + 5] xor b[c + 10] xor b[c + 15] xor b[c + 20]

template THETA2(a, b, c: untyped) =
  a = b[(c + 4) mod 5] xor ROL(uint64(b[(c + 1) mod 5]), 1)

template THETA3(a, b, c) =
  a[b] = a[b] xor c
  a[b + 5] = a[b + 5] xor c
  a[b + 10] = a[b + 10] xor c
  a[b + 15] = a[b + 15] xor c
  a[b + 20] = a[b + 20] xor c

template RHOPI(a, b, c, d, e) =
  a[0] = b[d]
  b[d] = ROL(c, e)
  c = a[0]

template CHI(a, b, c) =
  a[0] = b[c]
  a[1] = b[c + 1]
  a[2] = b[c + 2]
  a[3] = b[c + 3]
  a[4] = b[c + 4]
  b[c] = b[c] xor (not(a[1]) and a[2])
  b[c + 1] = b[c + 1] xor (not(a[2]) and a[3])
  b[c + 2] = b[c + 2] xor (not(a[3]) and a[4])
  b[c + 3] = b[c + 3] xor (not(a[4]) and a[0])
  b[c + 4] = b[c + 4] xor (not(a[0]) and a[1])

template KECCAKROUND(a, b, c, r) =
  THETA1(b, a, 0)
  THETA1(b, a, 1)
  THETA1(b, a, 2)
  THETA1(b, a, 3)
  THETA1(b, a, 4)
  THETA2(c, b, 0)
  THETA3(a, 0, c)
  THETA2(c, b, 1)
  THETA3(a, 1, c)
  THETA2(c, b, 2)
  THETA3(a, 2, c)
  THETA2(c, b, 3)
  THETA3(a, 3, c)
  THETA2(c, b, 4)
  THETA3(a, 4, c)
  c = a[1]
  RHOPI(b, a, c, 10, 1)
  RHOPI(b, a, c, 7, 3)
  RHOPI(b, a, c, 11, 6)
  RHOPI(b, a, c, 17, 10)
  RHOPI(b, a, c, 18, 15)
  RHOPI(b, a, c, 3, 21)
  RHOPI(b, a, c, 5, 28)
  RHOPI(b, a, c, 16, 36)
  RHOPI(b, a, c, 8, 45)
  RHOPI(b, a, c, 21, 55)
  RHOPI(b, a, c, 24, 2)
  RHOPI(b, a, c, 4, 14)
  RHOPI(b, a, c, 15, 27)
  RHOPI(b, a, c, 23, 41)
  RHOPI(b, a, c, 19, 56)
  RHOPI(b, a, c, 13, 8)
  RHOPI(b, a, c, 12, 25)
  RHOPI(b, a, c, 2, 43)
  RHOPI(b, a, c, 20, 62)
  RHOPI(b, a, c, 14, 18)
  RHOPI(b, a, c, 22, 39)
  RHOPI(b, a, c, 9, 61)
  RHOPI(b, a, c, 6, 20)
  RHOPI(b, a, c, 1, 44)
  CHI(b, a, 0)
  CHI(b, a, 5)
  CHI(b, a, 10)
  CHI(b, a, 15)
  CHI(b, a, 20)
  a[0] = a[0] xor RNDC[r]

func keccakTransform(data: var array[200, byte]) =
  var
    bc: array[5, uint64]
    st: array[25, uint64]
    t: uint64
  st[0] = leLoad64(data, 0)
  st[1] = leLoad64(data, 8)
  st[2] = leLoad64(data, 16)
  st[3] = leLoad64(data, 24)
  st[4] = leLoad64(data, 32)
  st[5] = leLoad64(data, 40)
  st[6] = leLoad64(data, 48)
  st[7] = leLoad64(data, 56)
  st[8] = leLoad64(data, 64)
  st[9] = leLoad64(data, 72)
  st[10] = leLoad64(data, 80)
  st[11] = leLoad64(data, 88)
  st[12] = leLoad64(data, 96)
  st[13] = leLoad64(data, 104)
  st[14] = leLoad64(data, 112)
  st[15] = leLoad64(data, 120)
  st[16] = leLoad64(data, 128)
  st[17] = leLoad64(data, 136)
  st[18] = leLoad64(data, 144)
  st[19] = leLoad64(data, 152)
  st[20] = leLoad64(data, 160)
  st[21] = leLoad64(data, 168)
  st[22] = leLoad64(data, 176)
  st[23] = leLoad64(data, 184)
  st[24] = leLoad64(data, 192)
  KECCAKROUND(st, bc, t, 0)
  KECCAKROUND(st, bc, t, 1)
  KECCAKROUND(st, bc, t, 2)
  KECCAKROUND(st, bc, t, 3)
  KECCAKROUND(st, bc, t, 4)
  KECCAKROUND(st, bc, t, 5)
  KECCAKROUND(st, bc, t, 6)
  KECCAKROUND(st, bc, t, 7)
  KECCAKROUND(st, bc, t, 8)
  KECCAKROUND(st, bc, t, 9)
  KECCAKROUND(st, bc, t, 10)
  KECCAKROUND(st, bc, t, 11)
  KECCAKROUND(st, bc, t, 12)
  KECCAKROUND(st, bc, t, 13)
  KECCAKROUND(st, bc, t, 14)
  KECCAKROUND(st, bc, t, 15)
  KECCAKROUND(st, bc, t, 16)
  KECCAKROUND(st, bc, t, 17)
  KECCAKROUND(st, bc, t, 18)
  KECCAKROUND(st, bc, t, 19)
  KECCAKROUND(st, bc, t, 20)
  KECCAKROUND(st, bc, t, 21)
  KECCAKROUND(st, bc, t, 22)
  KECCAKROUND(st, bc, t, 23)
  leStore64(data, 0, st[0])
  leStore64(data, 8, st[1])
  leStore64(data, 16, st[2])
  leStore64(data, 24, st[3])
  leStore64(data, 32, st[4])
  leStore64(data, 40, st[5])
  leStore64(data, 48, st[6])
  leStore64(data, 56, st[7])
  leStore64(data, 64, st[8])
  leStore64(data, 72, st[9])
  leStore64(data, 80, st[10])
  leStore64(data, 88, st[11])
  leStore64(data, 96, st[12])
  leStore64(data, 104, st[13])
  leStore64(data, 112, st[14])
  leStore64(data, 120, st[15])
  leStore64(data, 128, st[16])
  leStore64(data, 136, st[17])
  leStore64(data, 144, st[18])
  leStore64(data, 152, st[19])
  leStore64(data, 160, st[20])
  leStore64(data, 168, st[21])
  leStore64(data, 176, st[22])
  leStore64(data, 184, st[23])
  leStore64(data, 192, st[24])

func update*(ctx: var KeccakContext,
             data: openArray[byte]) =
  var j = ctx.pt
  if len(data) > 0:
    for i in 0 ..< len(data):
      ctx.q[j] = ctx.q[j] xor data[i]
      inc(j)
      if j >= 200 - 2 * (ctx.bits div 8):
        keccakTransform(ctx.q)
        j = 0
    ctx.pt = j

func finish*(
    ctx: var KeccakContext,
    data: var openArray[byte]
): uint =
  ctx.q[ctx.pt] = ctx.q[ctx.pt] xor 0x01'u8
  ctx.q[200 - 2 * (ctx.bits div 8) - 1] = ctx.q[200 - 2 * (ctx.bits div 8) - 1] xor 0x80'u8
  keccakTransform(ctx.q)
  if len(data) >= ctx.bits div 8:
    for i in 0 ..< ctx.bits div 8:
      data[i] = ctx.q[i]
    result = uint(ctx.bits div 8)

func finish*(ctx: var KeccakContext): MDigest[ctx.bits] =
  discard finish(ctx, result.data)
