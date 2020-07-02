# byteutils
# Copyright (c) 2018 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import  unittest,
        ../stew/byteutils

proc compilationTest {.exportc: "compilationTest".} =
  var bytes = @[1.byte, 2, 3, 4]
  writeFile("test", bytes)

suite "Byte utils":
  let simpleBArray = [0x12.byte, 0x34, 0x56, 0x78]

  test "hexToByteArray: Inplace partial string":
    let s = "0x1234567890"
    var a: array[5, byte]
    hexToByteArray(s, a, 1, 3)
    check a == [0.byte, 0x34, 0x56, 0x78, 0]

  test "hexToByteArray: Inplace full string":
    let s = "0xffffffff"
    var a: array[4, byte]
    hexToByteArray(s, a)
    check a == [255.byte, 255, 255, 255]

  test "hexToByteArray: Return array":
    let
      s = "0x12345678"
      a = hexToByteArray[4](s)
    check a == simpleBArray

    expect(ValueError): discard hexToByteArray[1]("")
    expect(ValueError): discard hexToByteArray[1]("1")

  test "array.fromHex":
    let
      s = "0x12345678"
      a2 = array[2, byte].fromHex(s)
      a4 = array[4, byte].fromHex(s)

    check:
      a2.toHex == "1234"
      a4.toHex == "12345678"

    expect(ValueError): echo array[5, byte].fromHex(s)

  test "toHex":
    check simpleBArray.toHex == "12345678"
    check hexToSeqByte("12345678") == simpleBArray
    check hexToSeqByte("00") == [byte 0]
    check hexToSeqByte("0x") == []
    expect(ValueError): discard hexToSeqByte("1234567")
    expect(ValueError): discard hexToSeqByte("X")
    expect(ValueError): discard hexToSeqByte("0")

  test "Array concatenation":
    check simpleBArray & simpleBArray ==
      [0x12.byte, 0x34, 0x56, 0x78, 0x12, 0x34, 0x56, 0x78]

  test "hexToPaddedByteArray":
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

  test "lessThan":
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

  test "strings":
    check:
      "a".toBytes() == @[byte(ord('a'))]
      string.fromBytes([byte(ord('a'))]) == "a"
      cast[ptr UncheckedArray[byte]](cstring(string.fromBytes([byte(ord('a'))])))[1] == byte(0)

      "".toBytes().len() == 0
      string.fromBytes([]) == ""
      @[byte(ord('a'))] == static("a".toBytes())
      "a" == static(string.fromBytes([byte(ord('a'))]))
  test "slices":
    var a: array[4, byte]
    a[0..<2] = [2'u8, 3]
    check:
      a[1] == 3

    a.toOpenArray(0, 3)[0..<2] = [4'u8, 5]
    check:
      a[1] == 5
