import unittest

import ../stew/endians2

template test() =
  when sizeof(uint) == 4:
    const
      forwardInt = 0x01234567'u
      forwardBytes = [0x01'u8, 0x23'u8, 0x45'u8, 0x67'u8]
      reverseBytes = [0x67'u8, 0x45'u8, 0x23'u8, 0x01'u8]
  elif sizeof(uint) == 8:
    const
      forwardInt = 0x0123456789abcdef'u
      forwardBytes = [
        0x01'u8, 0x23'u8, 0x45'u8, 0x67'u8, 0x89'u8, 0xab'u8, 0xcd'u8, 0xef'u8]
      reverseBytes = [
        0xef'u8, 0xcd'u8, 0xab'u8, 0x89'u8, 0x67'u8, 0x45'u8, 0x23'u8, 0x01'u8]
  else:
    static: doAssert false, "requires a 32-bit or 64-bit platform"

  doAssert 0x01'u8.toBytesBE == [0x01'u8]
  doAssert 0x0123'u16.toBytesBE == [0x01'u8, 0x23'u8]
  doAssert 0x01234567'u32.toBytesBE == [0x01'u8, 0x23'u8, 0x45'u8, 0x67'u8]
  doAssert 0x0123456789abcdef'u64.toBytesBE == [
    0x01'u8, 0x23'u8, 0x45'u8, 0x67'u8, 0x89'u8, 0xab'u8, 0xcd'u8, 0xef'u8]
  doAssert forwardInt.toBytesBE == forwardBytes

  doAssert 0x01'u8.toBytesLE == [0x01'u8]
  doAssert 0x0123'u16.toBytesLE == [0x23'u8, 0x01'u8]
  doAssert 0x01234567'u32.toBytesLE == [0x67'u8, 0x45'u8, 0x23'u8, 0x01'u8]
  doAssert 0x0123456789abcdef'u64.toBytesLE == [
    0xef'u8, 0xcd'u8, 0xab'u8, 0x89'u8, 0x67'u8, 0x45'u8, 0x23'u8, 0x01'u8]
  doAssert forwardInt.toBytesLE == reverseBytes

  doAssert 0x01'u8 == uint8.fromBytesBE([0x01'u8])
  doAssert 0x0123'u16 == uint16.fromBytesBE([0x01'u8, 0x23'u8])
  doAssert 0x01234567'u32 == uint32.fromBytesBE(
    [0x01'u8, 0x23'u8, 0x45'u8, 0x67'u8])
  doAssert 0x0123456789abcdef'u64 == uint64.fromBytesBE(
    [0x01'u8, 0x23'u8, 0x45'u8, 0x67'u8, 0x89'u8, 0xab'u8, 0xcd'u8, 0xef'u8])
  doAssert forwardInt == uint.fromBytesBE(forwardBytes)

  doAssert 0x01'u8 == uint8.fromBytesLE([0x01'u8])
  doAssert 0x0123'u16 == uint16.fromBytesLE([0x23'u8, 0x01'u8])
  doAssert 0x01234567'u32 == uint32.fromBytesLE(
    [0x67'u8, 0x45'u8, 0x23'u8, 0x01'u8])
  doAssert 0x0123456789abcdef'u64 == uint64.fromBytesLE([
    0xef'u8, 0xcd'u8, 0xab'u8, 0x89'u8, 0x67'u8, 0x45'u8, 0x23'u8, 0x01'u8])
  doAssert forwardInt == uint.fromBytesLE(reverseBytes)

  doAssert 0x01234567'u32.swapBytes() == 0x67452301

static: test()

suite "endians2":
  test "endians2_test":
    test() # Cannot use unittest at compile time..
