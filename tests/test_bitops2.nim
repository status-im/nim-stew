# Copyright (c) 2019-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import unittest2

import ../stew/bitops2

template test() =
  doAssert bitsof(8'u8) == 8
  doAssert bitsof(uint64) == 64

  doAssert countOnes(0b00000000'u8) == 0
  doAssert countOnes(0b01000100'u8) == 2
  doAssert countOnes(0b11111111'u64) == 8
  doAssert countOnes(0b11000001'u) == 3

  doAssert countZeros(0b00000000'u8) == 8
  doAssert countZeros(0b01000100'u8) == 6
  doAssert countZeros(0b11111111'u64) == 56

  doAssert firstOne(0b00000000'u8) == 0
  doAssert firstOne(0b00000001'u64) == 1
  doAssert firstOne(0b00010010'u8) == 2
  doAssert firstOne(0b11111111'u8) == 1
  doAssert firstOne(0b100000000000000000000000000000000'u64) == 33
  doAssert firstOne(0b00000010_00000000_00000000_00000000_00000000_00000000_00000000_00000000'u64) == 8*7 + 2
  doAssert firstOne(0b11111111'u) == 1

  doAssert leadingZeros(0b00000000'u8) == 8
  doAssert leadingZeros(0b00000001'u8) == 7
  doAssert leadingZeros(0b00100000'u8) == 2
  doAssert leadingZeros(0b10000000'u8) == 0
  doAssert leadingZeros(0b10000000'u16) == 8
  doAssert leadingZeros(0b10000000'u32) == 24
  doAssert leadingZeros(0b10000000'u64) == 56
  when defined(cpu64):
    doAssert leadingZeros(0b00000001'u) == 63
  else:
    doAssert leadingZeros(0b00000001'u) == 31

  doAssert log2trunc(0b00000000'u8) == -1
  doAssert log2trunc(0b00000001'u8) == 0
  doAssert log2trunc(0b00000010'u8) == 1
  doAssert log2trunc(0b01000000'u8) == 6
  doAssert log2trunc(0b01001000'u8) == 6
  doAssert log2trunc(0b10001000'u64) == 7
  doAssert log2trunc(0b01000000'u) == 6

  doAssert nextPow2(0'u64) == 0
  doAssert nextPow2(3'u64) == 4
  doAssert nextPow2(4'u32) == 4
  doAssert nextPow2(4'u) == 4

  doAssert parity(0b00000001'u8) == 1
  doAssert parity(0b10000001'u64) == 0
  doAssert parity(0b00000001'u) == 1

  doAssert rotateLeft(0b01000001'u8, 2) == 0b00000101'u8
  doAssert rotateRight(0b01000001'u8, 2) == 0b01010000'u8
  doAssert rotateLeft(0b01000001'u, 2) == 0b100000100'u
  doAssert rotateRight(0b0100000100'u, 2) == 0b01000001'u

  doAssert trailingZeros(0b00000000'u8) == 8
  doAssert trailingZeros(0b00100000'u8) == 5
  doAssert trailingZeros(0b00100001'u8) == 0
  doAssert trailingZeros(0b10000000'u8) == 7
  doAssert trailingZeros(0b10000000'u16) == 7
  doAssert trailingZeros(0b10000000'u32) == 7
  doAssert trailingZeros(0b10000000'u64) == 7
  doAssert trailingZeros(0b10000000'u) == 7

  var bit: uint8
  setBit(bit, 0)
  setBit(bit, 7)
  doAssert bit == 0b10000001'u8

  clearBit(bit, 0)
  doAssert bit == 0b10000000'u8

  setBitBE(bit, 1)
  doAssert bit == 0b11000000'u8

  clearBitBE(bit, 1)
  doAssert bit == 0b10000000'u8

  toggleBit(bit, 7)
  toggleBit(bit, 6)
  doAssert bit == 0b01000000'u8

  changeBit(bit, 5, true)
  changeBit(bit, 6, false)
  doAssert bit == 0b00100000'u8

  changeBit(bit, 5, true)
  changeBit(bit, 6, false)
  doAssert bit == 0b00100000'u8 # no change!

  changeBitBE(bit, 1, true)
  changeBitBE(bit, 2, false)
  doAssert bit == 0b01000000'u8

  var bit64: uint64
  setBit(bit64, 63)

  # T(1 shl 63) raises!
  doAssert bit64 == 0b10000000_00000000_00000000_00000000_00000000_00000000_00000000_00000000'u64

proc runtimeTest =
  var bytes = @[byte 0b11001101, 0b10010010, 0b00000000, 0b11111111,
                     0b11000010, 0b00110110, 0b11010110, 0b00101010,
                     0b01101110, 0b11101001, 0b10101011, 0b00110010]

  doAssert getBitsBE(bytes, 0..0, byte) == byte(1)
  doAssert getBitsBE(bytes, 1..1, byte) == byte(1)
  doAssert getBitsBE(bytes, 2..2, byte) == byte(0)
  doAssert getBitsBE(bytes, 6..6, byte) == byte(0)
  doAssert getBitsBE(bytes, 7..7, byte) == byte(1)

  doAssert getBitsBE(bytes, 0..1, byte) == byte(0b11)
  doAssert getBitsBE(bytes, 1..2, byte) == byte(0b10)
  doAssert getBitsBE(bytes, 2..3, byte) == byte(0)
  doAssert getBitsBE(bytes, 5..6, byte) == byte(0b10)
  doAssert getBitsBE(bytes, 6..7, byte) == byte(0b1)

  doAssert getBitsBE(bytes, 7..8, byte) == byte(0b11)

  doAssert getBitsBE(bytes, 0..2, byte) == byte(0b110)
  doAssert getBitsBE(bytes, 1..3, byte) == byte(0b100)
  doAssert getBitsBE(bytes, 6..9, byte) == byte(0b110)

  doAssert getBitsBE(bytes, 0..3, byte) == byte(0b1100)
  doAssert getBitsBE(bytes, 0..7, byte) == byte(0b11001101)

  doAssert getBitsBE(bytes, 0..10, uint16) == uint16(0b11001101100)
  doAssert getBitsBE(bytes, 0..15, uint16) == uint16(0b1100110110010010)
  doAssert getBitsBE(bytes, 1..11, uint16) == uint16(0b10011011001)
  doAssert getBitsBE(bytes, 3..18, uint16) == uint16(0b110110010010000)
  doAssert getBitsBE(bytes, 35..50, uint16) == uint16(0b1000110110110)

  doAssert getBitsBE(bytes, 4..7, uint16) == uint16(0b1101)
  doAssert getBitsBE(bytes, 1..29) == 0b10011011001001000000000111111'u64
  doAssert getBitsBE(bytes, 1..25, uint32) == 0b1001101100100100000000011'u32
  doAssert getBitsBE(bytes, 1..25, uint32) == 0b1001101100100100000000011'u32

static: test()

suite "bitops2":
  test "bitops2_test":
    test() # Cannot use unittest at compile time..
    runtimeTest()
