import unittest2
import ../stew/base10

when defined(nimHasUsed): {.used.}

const
  DecVectors = [
    ("0", 0'u64, 1),
    ("1", 1'u64, 1),
    ("9", 9'u64, 1),
    ("10", 10'u64, 2),
    ("11", 11'u64, 2),
    ("99", 99'u64, 2),
    ("100", 100'u64, 3),
    ("101", 101'u64, 3),
    ("255", 255'u64, 3), # end of uint8
    ("256", 256'u64, 3),
    ("999", 999'u64, 3),
    ("1000", 1000'u64, 4),
    ("1001", 1001'u64, 4),
    ("9999", 9999'u64, 4),
    ("10000", 10000'u64, 5),
    ("10001", 10001'u64, 5),
    ("65535", 65535'u64, 5), # end of uint16
    ("65536", 65536'u64, 5),
    ("99999", 99999'u64, 5),
    ("100000", 100000'u64, 6),
    ("100001", 100001'u64, 6),
    ("999999", 999999'u64, 6),
    ("1000000", 1000000'u64, 7),
    ("1000001", 1000001'u64, 7),
    ("9999999", 9999999'u64, 7),
    ("10000000", 10000000'u64, 8),
    ("10000001", 10000001'u64, 8),
    ("99999999", 99999999'u64, 8),
    ("100000000", 100000000'u64, 9),
    ("100000001", 100000001'u64, 9),
    ("999999999", 999999999'u64, 9),
    ("1000000000", 1000000000'u64, 10),
    ("1000000001", 1000000001'u64, 10),
    ("4294967295", 4294967295'u64, 10), # end of uint32
    ("4294967296", 4294967296'u64, 10),
    ("9999999999", 9999999999'u64, 10),
    ("10000000000", 10000000000'u64, 11),
    ("10000000001", 10000000001'u64, 11),
    ("99999999999", 99999999999'u64, 11),
    ("100000000000", 100000000000'u64, 12),
    ("100000000001", 100000000001'u64, 12),
    ("999999999999", 999999999999'u64, 12),
    ("1000000000000", 1000000000000'u64, 13),
    ("1000000000001", 1000000000001'u64, 13),
    ("9999999999999", 9999999999999'u64, 13),
    ("10000000000000", 10000000000000'u64, 14),
    ("10000000000001", 10000000000001'u64, 14),
    ("99999999999999", 99999999999999'u64, 14),
    ("100000000000000", 100000000000000'u64, 15),
    ("100000000000001", 100000000000001'u64, 15),
    ("999999999999999", 999999999999999'u64, 15),
    ("1000000000000000", 1000000000000000'u64, 16),
    ("1000000000000001", 1000000000000001'u64, 16),
    ("9999999999999999", 9999999999999999'u64, 16),
    ("10000000000000000", 10000000000000000'u64, 17),
    ("10000000000000001", 10000000000000001'u64, 17),
    ("99999999999999999", 99999999999999999'u64, 17),
    ("100000000000000000", 100000000000000000'u64, 18),
    ("100000000000000001", 100000000000000001'u64, 18),
    ("999999999999999999", 999999999999999999'u64, 18),
    ("1000000000000000000", 1000000000000000000'u64, 19),
    ("1000000000000000001", 1000000000000000001'u64, 19),
    ("9999999999999999999", 9999999999999999999'u64, 19),
    ("10000000000000000000", 10000000000000000000'u64, 20),
    ("10000000000000000001", 10000000000000000001'u64, 20),
    ("18446744073709551615", 18446744073709551615'u64, 20), # end of uint64
    ("18446744073709551616", 0'u64, 0),
    ("99999999999999999999", 0'u64, 0)
  ]

template testVectors(T: typedesc[SomeUnsignedInt]) =
  let max = uint64(high(T))
  for item in DecVectors:
    if (item[1] <= max) and (item[2] != 0):
      let r1 = Base10.decode(T, item[0])
      let r2 = Base10.decode(T, cast[seq[byte]](item[0]))
      check:
        r1.isOk()
        r2.isOk()
        r1.get() == item[1]
        r2.get() == item[1]
        Base10.encodedLength(item[1]) == item[2]
      var outbuf = newSeq[byte](Base10.encodedLength(item[1]))
      var outstr = newString(Base10.encodedLength(item[1]))
      let r3 = Base10.encode(T(item[1]), outbuf)
      let r4 = Base10.encode(T(item[1]), outstr)

      check:
        r3.isOk()
        r4.isOk()
        r3.get() == Base10.encodedLength(item[1])
        r4.get() == Base10.encodedLength(item[1])
        cast[string](outbuf) == item[0]
        outstr == item[0]

      var neoutbuf = newSeq[byte](Base10.encodedLength(item[1]) - 1)
      var neoutstr = newString(Base10.encodedLength(item[1]) - 1)
      let r5 = Base10.encode(T(item[1]), neoutbuf)
      let r6 = Base10.encode(T(item[1]), neoutstr)

      check:
        r5.isErr()
        r6.isErr()

    else:
      var emptySeq: seq[byte]
      var emptyStr: string
      let r1 = Base10.decode(T, emptyStr)
      let r2 = Base10.decode(T, emptySeq)
      check:
        r1.isErr()
        r2.isErr()

template testValues(T: typedesc[SomeUnsignedInt]) =
  let max = int(min(uint64(high(T)), 100000'u64)) + 1
  for i in 0 ..< max:
    let bufstr = Base10.toString(T(i))
    let bufarr1 = Base10.toBytes(T(i))
    let bufarr2 = T(i).toBytes(Base10)
    let r1 = Base10.decode(T, bufstr)
    let r2 = Base10.decode(T, bufarr1.data.toOpenArray(0, bufarr1.len - 1))
    let r3 = Base10.decode(T, bufarr2.data.toOpenArray(0, bufarr2.len - 1))
    check:
      r1.isOk()
      r2.isOk()
      r3.isOk()
      r1.get() == T(i)
      r2.get() == T(i)
      r3.get() == T(i)


template testEdge(T: typedesc[SomeUnsignedInt]) =
  var bufstr: string
  var bufseq: seq[byte]
  let r1 = Base10.decode(T, bufstr)
  let r2 = Base10.decode(T, bufseq)
  check:
    r1.isErr()
    r2.isErr()

  var buf1str = newString(1)
  var buf1seq = newSeq[byte](1)
  for i in 0 ..< 256:
    let ch = char(i)
    if ch notin {'0'..'9'}:
      buf1str[0] = ch
      buf1seq[0] = byte(ch)
      let r3 = Base10.decode(T, buf1str)
      let r4 = Base10.decode(T, buf1seq)
      check:
        r3.isErr()
        r4.isErr()

template testHigh() =
  check:
    Base10.toString(uint8(high(int8))) == "127"
    Base10.toString(high(uint8)) == "255"
    Base10.toString(uint16(high(int16))) == "32767"
    Base10.toString(high(uint16)) == "65535"
    Base10.toString(uint32(high(int32))) == "2147483647"
    Base10.toString(high(uint32)) == "4294967295"
    Base10.toString(uint64(high(int64))) == "9223372036854775807"
    Base10.toString(high(uint64)) == "18446744073709551615"
    Base10.decode(uint8, "127").tryGet() == 127'u8
    Base10.decode(uint8, "255").tryGet() == 255'u8
    Base10.decode(uint16, "32767").tryGet() == 32767'u16
    Base10.decode(uint16, "65535").tryGet() == 65535'u16
    Base10.decode(uint32, "2147483647").tryGet() == 2147483647'u32
    Base10.decode(uint32, "4294967295").tryGet() == 4294967295'u32
    Base10.decode(uint64, "9223372036854775807").tryGet() ==
      9223372036854775807'u64
    Base10.decode(uint64, "18446744073709551615").tryGet() ==
      18446744073709551615'u64

  when sizeof(uint) == 8:
    check:
      Base10.toString(uint(high(int))) == "9223372036854775807"
      Base10.toString(high(uint)) == "18446744073709551615"
      Base10.decode(uint, "9223372036854775807").tryGet() ==
        9223372036854775807'u
      Base10.decode(uint, "18446744073709551615").tryGet() ==
        18446744073709551615'u
  elif sizeof(uint) == 4:
    check:
      Base10.toString(uint(high(int))) == "2147483647"
      Base10.toString(high(uint)) == "4294967295"
      Base10.decode(uint, "2147483647").tryGet() == 2147483647'u
      Base10.decode(uint, "4294967295").tryGet() == 4294967295'u
  else:
    skip()

suite "Base10 (decimal) test suite":
  test "[uint8] encode/decode/length test":
    testVectors(uint8)
  test "[uint16] encode/decode/length test":
    testVectors(uint16)
  test "[uint32] encode/decode/length test":
    testVectors(uint32)
  test "[uint64] encode/decode/length test":
    testVectors(uint64)
  test "[uint] encode/decode/length test":
    testVectors(uint)
  test "[uint8] all values comparison test":
    testValues(uint8)
  test "[uint16] all values comparison test":
    testValues(uint16)
  test "[uint32] 100,000 values comparison test":
    testValues(uint32)
  test "[uint64] 100,000 values comparison test":
    testValues(uint64)
  test "[uint] 100,000 values comparison test":
    testValues(uint)
  test "[uint8] edge cases":
    testEdge(uint8)
  test "[uint16] edge cases":
    testEdge(uint16)
  test "[uint32] edge cases":
    testEdge(uint32)
  test "[uint64] edge cases":
    testEdge(uint64)
  test "[uint] edge cases":
    testEdge(uint)
  test "high() values test":
    testHigh()
