# byteutils
# Copyright (c) 2018-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2,
  ../stew/byteutils

proc compilationTest {.exportc: "compilationTest".} =
  var bytes = @[1.byte, 2, 3, 4]
  writeFile("test", bytes)

func iterHex(ba: openArray[byte]): string =
  for c in toHex(ba):
    result.add c

func iter0xHex(ba: openArray[byte]): string =
  for c in to0xHex(ba):
    result.add c

suite "Byte utils":
  const simpleBArray = [0x12.byte, 0x34, 0x56, 0x78]

  dualTest "hexToByteArray: Inplace partial string":
    let s = "0x1234567890"
    var a: array[5, byte]
    hexToByteArray(s, a, 1, 3)
    check a == [0.byte, 0x34, 0x56, 0x78, 0]

  dualTest "hexToByteArray: Inplace full string":
    let s = "0xffffffff"
    var a: array[4, byte]
    hexToByteArray(s, a)
    check a == [255.byte, 255, 255, 255]

  dualTest "hexToByteArrayStrict":
    let
      short0 = ""
      short1 = "0x"
      short2 = "0x00"
      short3 = "0xffffff"
      short4 = "0xfffffff"
      correct = "0xffffffff"
      long1 = "0xfffffffff"
      long2 = "0xffffffffff"

    var a: array[4, byte]
    hexToByteArrayStrict(correct, a)
    check a == [255.byte, 255, 255, 255]

    template reject(val: string) =
      expect ValueError: hexToByteArrayStrict(val, a)

    reject short0
    reject short1
    reject short2
    reject short3
    reject short4
    reject long1
    reject long2

  dualTest "hexToByteArray: Return array":
    let
      s = "0x12345678"
      a = hexToByteArray[4](s)
    check a == simpleBArray

    expect(ValueError): discard hexToByteArray[1]("")
    expect(ValueError): discard hexToByteArray[1]("1")

  dualTest "hexToByteArray: missing bytes":
    var buffer: array[1, byte]
    expect(ValueError):
      hexToByteArray("0x", buffer)
    expect(ValueError):
      hexToByteArray("", buffer)
    expect(ValueError):
      hexToByteArray("0", buffer)

  dualTest "valid hex with empty array":
    var buffer: seq[byte]
    hexToByteArray("0x123", openArray[byte](buffer))
    check(buffer == seq[byte](@[]))

  dualTest "valid hex with empty array of size":
    var buffer: seq[byte] = newSeq[byte](4)
    hexToByteArray("00000123", openArray[byte](buffer))
    check(buffer == @[0.byte, 0.byte, 1.byte, 35.byte])
    check buffer.toHex == "00000123"

  dualTest "empty output array is ok":
    var output: array[0, byte]

    hexToByteArray("", output)
    hexToByteArray("0x", output)
    hexToByteArray("0x32", output)

  dualTest "array.fromHex":
    let
      s = "0x12345678"
      a2 = array[2, byte].fromHex(s)
      a4 = array[4, byte].fromHex(s)

    check:
      a2.toHex == "1234"
      a4.toHex == "12345678"

    expect(ValueError): echo array[5, byte].fromHex(s)

  dualTest "toHex":
    check toHex(default(seq[byte])) == ""
    check simpleBArray.toHex == "12345678"
    check simpleBArray.iterHex == "12345678"
    check hexToSeqByte("12345678") == simpleBArray
    check hexToSeqByte("00") == [byte 0]
    check hexToSeqByte("0x") == []
    expect(ValueError): discard hexToSeqByte("1234567")
    expect(ValueError): discard hexToSeqByte("X")
    expect(ValueError): discard hexToSeqByte("0")
    check to0xHex(default(seq[byte])) == "0x"
    check simpleBArray.to0xHex == "0x12345678"
    check simpleBArray.iter0xHex == "0x12345678"

  dualTest "toHex: every byte value":
    var bytes = newSeq[byte](256)
    for i in 0 ..< 256:
      bytes[i] = byte(i)

    const expected =
      "000102030405060708090a0b0c0d0e0f101112131415161718" &
      "191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f3031" &
      "32333435363738393a3b3c3d3e3f404142434445464748494a" &
      "4b4c4d4e4f505152535455565758595a5b5c5d5e5f60616263" &
      "6465666768696a6b6c6d6e6f707172737475767778797a7b7c" &
      "7d7e7f808182838485868788898a8b8c8d8e8f909192939495" &
      "969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadae" &
      "afb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7" &
      "c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0" &
      "e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff"

    check:
      bytes.toHex == expected
      bytes.to0xHex == "0x" & expected
      iterHex(bytes) == expected
      iter0xHex(bytes) == "0x" & expected
      hexToSeqByte(bytes.toHex) == bytes
      hexToSeqByte(bytes.to0xHex) == bytes

  test "Array concatenation":
    check simpleBArray & simpleBArray ==
      [0x12.byte, 0x34, 0x56, 0x78, 0x12, 0x34, 0x56, 0x78]

  dualTest "hexToPaddedByteArray":
    block:
      let a = hexToPaddedByteArray[4]("0x123")
      check a.toHex == "00000123"
    block:
      let a = hexToPaddedByteArray[4]("0x1234")
      check a.toHex == "00001234"
    block:
      let a = hexToPaddedByteArray[4]("0x1234567")
      check a.toHex == "01234567"
    block:
      let a = hexToPaddedByteArray[4]("0x12345678")
      check a.toHex == "12345678"
    block:
      let a = hexToPaddedByteArray[32]("0x68656c6c6f20776f726c64")
      check a.toHex == "00000000000000000000000000000000000000000068656c6c6f20776f726c64"
    block:
      expect ValueError:
        discard hexToPaddedByteArray[2]("0x12345")

  dualTest "lessThan":
    let
      a = [0'u8, 1, 2]
      b = [2'u8, 1, 0]
      c = [0'u8, 1, 2, 3]
      d = [0'u8, 1, 3, 3]

    check:
      not (a < a)

      a < b
      not (b < a)

      c < b
      not (b < c)

      a < c
      not (c < a)

      c < d
      not (d < c)

  proc copyView(v: openArray[char]): seq[byte] =
    v.toBytes()

  dualTest "strings":
    check:
      "a".toBytes() == @[byte(ord('a'))]
      copyView("a") == @[byte(ord('a'))]

      string.fromBytes([byte(ord('a'))]) == "a"

      "".toBytes().len() == 0
      string.fromBytes([]) == ""
      @[byte(ord('a'))] == static("a".toBytes())
      "a" == static(string.fromBytes([byte(ord('a'))]))

  test "strings cast":
    check:
      cast[ptr UncheckedArray[byte]](cstring(string.fromBytes([byte(ord('a'))])))[1] == byte(0)

  test "slices":
    var a: array[4, byte]
    a[0..<2] = [2'u8, 3]
    check:
      a[1] == 3

    a.toOpenArray(0, 3)[0..<2] = [4'u8, 5]
    check:
      a[1] == 5
