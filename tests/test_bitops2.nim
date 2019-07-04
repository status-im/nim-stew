import unittest

import ../stew/bitops2

template test() =
  doAssert bitsof(8'u8) == 8
  doAssert bitsof(uint64) == 64

  doAssert countOnes(0b00000000'u8) == 0
  doAssert countOnes(0b01000100'u8) == 2
  doAssert countOnes(0b11111111'u64) == 8

  doAssert firstOne(0b00000000'u8) == 0
  doAssert firstOne(0b00000001'u64) == 1
  doAssert firstOne(0b00010010'u8) == 2
  doAssert firstOne(0b11111111'u8) == 1
  doAssert firstOne(0b100000000000000000000000000000000'u64) == 33

  doAssert leadingZeros(0b00000000'u8) == 8
  doAssert leadingZeros(0b00000001'u8) == 7
  doAssert leadingZeros(0b00100000'u8) == 2
  doAssert leadingZeros(0b10000000'u8) == 0
  doAssert leadingZeros(0b10000000'u16) == 8
  doAssert leadingZeros(0b10000000'u32) == 24
  doAssert leadingZeros(0b10000000'u64) == 56

  doAssert log2trunc(0b00000000'u8) == -1
  doAssert log2trunc(0b00000001'u8) == 0
  doAssert log2trunc(0b00000010'u8) == 1
  doAssert log2trunc(0b01000000'u8) == 6
  doAssert log2trunc(0b01001000'u8) == 6
  doAssert log2trunc(0b10001000'u64) == 7

  doAssert nextPow2(0'u64) == 0
  doAssert nextPow2(3'u64) == 4
  doAssert nextPow2(4'u32) == 4

  doAssert parity(0b00000001'u8) == 1
  doAssert parity(0b10000001'u64) == 0

  doAssert rotateLeft(0b01000001'u8, 2) == 0b00000101'u8
  doAssert rotateRight(0b01000001'u8, 2) == 0b01010000'u8

  doAssert trailingZeros(0b00000000'u8) == 8
  doAssert trailingZeros(0b00100000'u8) == 5
  doAssert trailingZeros(0b00100001'u8) == 0
  doAssert trailingZeros(0b10000000'u8) == 7
  doAssert trailingZeros(0b10000000'u16) == 7
  doAssert trailingZeros(0b10000000'u32) == 7
  doAssert trailingZeros(0b10000000'u64) == 7

static: test()

suite "bitops2":
  test "bitops2_test":
    test() # Cannot use unittest at compile time..
