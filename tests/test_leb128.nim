import
  unittest2, random,
  ../stew/[byteutils, leb128, results]

const edgeValues = {
  0'u64                     : "00",
  1'u64                     : "01",
  (1'u64 shl 7) - 1'u64     : "7f",
  (1'u64 shl 7)             : "8001",
  (1'u64 shl 7) + 1'u64     : "8101",
  (1'u64 shl 14) - 1'u64    : "ff7f",
  (1'u64 shl 14)            : "808001",
  (1'u64 shl 21) - 1'u64    : "ffff7f",
  (1'u64 shl 21)            : "80808001",
  (1'u64 shl 28) - 1'u64    : "ffffff7f",
  (1'u64 shl 28)            : "8080808001",
  (1'u64 shl 35) - 1'u64    : "ffffffff7f",
  (1'u64 shl 35)            : "808080808001",
  (1'u64 shl 42) - 1'u64    : "ffffffffff7f",
  (1'u64 shl 42)            : "80808080808001",
  (1'u64 shl 49) - 1'u64    : "ffffffffffff7f",
  (1'u64 shl 49)            : "8080808080808001",
  (1'u64 shl 56) - 1'u64    : "ffffffffffffff7f",
  (1'u64 shl 56)            : "808080808080808001",
  (1'u64 shl 63) - 1'u64    : "ffffffffffffffff7f",
  (1'u64 shl 63)            : "80808080808080808001",
  0xFFFF_FFFF_FFFF_FFFF'u64 : "ffffffffffffffffff01"
}

suite "leb128":
  template roundtripTest(value: typed) =
    let
      leb {.inject.} = value.toBytes(Leb128)
      roundtripVal = type(value).fromBytes(leb.toOpenArray(), Leb128)

    check:
      value == roundtripVal.val

  test "Success edge cases test":
    for pair in edgeValues:
      let (value, hex) = pair
      roundtripTest value
      check:
        toHex(leb.toOpenArray()) == hex

  test "roundtrip random values":
    template testSome(T: type) =
      for i in 0..10000:
        # TODO nim 1.0 random casts limits to int, so anything bigger will crash
        #      * sigh *
        #      https://github.com/nim-lang/Nim/issues/16360
        let
          v1 = rand(T(0) .. cast[T](int.high))
        roundtripTest v1
    testSome(uint8)
    testSome(uint16)
    testSome(uint32)
    testSome(uint64)

  test "lengths":
    const lengths = {
      0'u64                     : 1,
      1'u64                     : 1,
      (1'u64 shl 7) - 1'u64     : 1,
      (1'u64 shl 7)             : 2,
      (1'u64 shl 7) + 1'u64     : 2,
      (1'u64 shl 14) - 1'u64    : 2,
      (1'u64 shl 14)            : 3,
      (1'u64 shl 21) - 1'u64    : 3,
      (1'u64 shl 21)            : 4,
      (1'u64 shl 28) - 1'u64    : 4,
      (1'u64 shl 28)            : 5,
      (1'u64 shl 35) - 1'u64    : 5,
      (1'u64 shl 35)            : 6,
      (1'u64 shl 42) - 1'u64    : 6,
      (1'u64 shl 42)            : 7,
      (1'u64 shl 49) - 1'u64    : 7,
      (1'u64 shl 49)            : 8,
      (1'u64 shl 56) - 1'u64    : 8,
      (1'u64 shl 56)            : 9,
      (1'u64 shl 63) - 1'u64    : 9,
      (1'u64 shl 63)            : 10,
      0xFFFF_FFFF_FFFF_FFFF'u64 : 10
    }

    for pair in lengths:
      check: Leb128.len(pair[0]) == pair[1]

  test "errors":
    check:
      uint8.fromBytes([0x80'u8], Leb128) == (0'u8, 0'i8)
      uint8.fromBytes([0x80'u8, 0x80], Leb128) == (0'u8, 0'i8)
      uint8.fromBytes(toBytes(256'u16, Leb128).toOpenArray(), Leb128).len < 0
      uint8.fromBytes([0x80'u8, 0x02], Leb128) == (0'u8, -2'i8) # 2 bytes consumed and overflow
      uint8.fromBytes([0x80'u8, 0x02, 0x05], Leb128) == (0'u8, -2'i8) # 2 bytes consumed and overflow
      uint64.fromBytes([0xff'u8, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x02], Leb128).len < 0
      uint64.fromBytes([0xff'u8, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], Leb128) == (0'u64, 0'i8)

    check:
      uint8.scan([0x80'u8], Leb128) == 0
      uint8.scan([0x80'u8, 0x80], Leb128) == 0
      uint8.scan(toBytes(256'u16, Leb128).toOpenArray(), Leb128) < 0
      uint64.scan([0xff'u8, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x02], Leb128) < 0
      uint64.scan([0xff'u8, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], Leb128) == 0
