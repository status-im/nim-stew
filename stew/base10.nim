## Copyright (c) 2021-2022 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements BASE10 (decimal) encoding and decoding procedures.
##
## Encoding procedures are adopted versions of C functions described here:
## # https://www.facebook.com/notes/facebook-engineering/three-optimization-tips-for-c/10151361643253920
import results
export results

when (NimMajor, NimMinor) < (1, 4):
  {.push raises: [Defect].}
else:
  {.push raises: [].}

type
  Base10* = object

func maxLen*(T: typedesc[Base10], I: type): int8 =
  ## The maximum number of bytes needed to encode any value of type I
  when I is uint8:
    3
  elif I is uint16:
    5
  elif I is uint32:
    10
  elif I is uint64:
    20
  else:
    when sizeof(uint) == 4:
      10
    else:
      20

type
  Base10Buf*[T: SomeUnsignedInt] = object
    data*: array[maxLen(Base10, T), byte]
    len*: int8 # >= 1 when holding valid unsigned integer

proc decode*[A: byte|char](B: typedesc[Base10], T: typedesc[SomeUnsignedInt],
                           src: openArray[A]): Result[T, cstring] =
  ## Convert base10 encoded string or array of bytes to unsigned integer.
  const
    MaxValue = T(high(T) div 10)
    MaxNumber = T(high(T) - MaxValue * 10)

  if len(src) == 0:
    return err("Missing decimal value")
  var v = T(0)
  for i in 0 ..< len(src):
    let ch = when A is char: byte(src[i]) else: src[i]
    let d =
      if (ch >= ord('0')) and (ch <= ord('9')):
        T(ch - ord('0'))
      else:
        return err("Non-decimal character encountered")
    if (v > MaxValue) or (v == MaxValue and T(d) > MaxNumber):
      return err("Integer overflow")
    v = (v shl 3) + (v shl 1) + T(d)
  ok(v)

proc encodedLength*(B: typedesc[Base10], value: SomeUnsignedInt): int8 =
  ## Procedure returns number of characters needed to encode integer ``value``.
  when type(value) is uint8:
    if value < 10'u8:
      return 1'i8
    if value < 100'u8:
      return 2'i8
    3'i8
  elif type(value) is uint16:
    if value < 10'u16:
      return 1'i8
    if value < 100'u16:
      return 2'i8
    if value < 1000'u16:
      return 3'i8
    if value < 10000'u16:
      return 4'i8
    5'i8
  elif (type(value) is uint32) or
       ((type(value) is uint) and (sizeof(uint) == 4)):
    const
      P04 = 1_0000'u32
      P05 = 1_0000_0'u32
      P06 = 1_0000_00'u32
      P07 = 1_0000_000'u32
      P08 = 1_0000_0000'u32
      P09 = 1_0000_0000_0'u32
    if value < 10'u32:
      return 1'i8
    if value < 100'u32:
      return 2'i8
    if value < 1000'u32:
      return 3'i8
    if value < P08:
      if value < P06:
        if value < P04:
          return 4'i8
        return 5'i8 + (if value >= P05: 1'i8 else: 0'i8)
      return 7'i8 + (if value >= P07: 1'i8 else: 0'i8)
    9'i8 + (if value >= P09: 1'i8 else: 0'i8)
  elif (type(value) is uint64) or
       ((type(value) is uint) and (sizeof(uint) == 8)):
    const
      P04 = 1_0000'u64
      P05 = 1_0000_0'u64
      P06 = 1_0000_00'u64
      P07 = 1_0000_000'u64
      P08 = 1_0000_0000'u64
      P09 = 1_0000_0000_0'u64
      P10 = 1_0000_0000_00'u64
      P11 = 1_0000_0000_000'u64
      P12 = 1_0000_0000_0000'u64
    if value < 10'u64:
      return 1'i8
    if value < 100'u64:
      return 2'i8
    if value < 1000'u64:
      return 3'i8
    if value < P12:
      if value < P08:
        if value < P06:
          if value < P04:
            return 4'i8
          return 5'i8 + (if value >= P05: 1'i8 else: 0)
        return 7'i8 + (if value >= P07: 1'i8 else: 0)
      if value < P10:
        return 9'i8 + (if value >= P09: 1'i8 else: 0)
      return 11'i8 + (if value >= P11: 1'i8 else: 0)
    return 12'i8 + B.encodedLength(value div P12)

proc encode[A: byte|char](B: typedesc[Base10], value: SomeUnsignedInt,
                          output: var openArray[A],
                          length: int8): Result[int8, cstring] =
  const Digits = cstring(
    "0001020304050607080910111213141516171819" &
    "2021222324252627282930313233343536373839" &
    "4041424344454647484950515253545556575859" &
    "6061626364656667686970717273747576777879" &
    "8081828384858687888990919293949596979899"
  )

  if len(output) < length:
    return err("Not enough space to store decimal value")

  var v = value
  var next = length - 1

  while v >= type(value)(100):
    let index = uint8((v mod type(value)(100)) shl 1)
    v = v div type(value)(100)
    when A is char:
      output[next] = Digits[index + 1]
      output[next - 1] = Digits[index]
    else:
      output[next] = byte(Digits[index + 1])
      output[next - 1] = byte(Digits[index])
    dec(next, 2)

  if v < type(value)(10):
    when A is char:
      output[next] = char(ord('0') + (v and type(value)(0x0F)))
    else:
      output[next] = byte('0') + byte(v and type(value)(0x0F))
  else:
    let index = uint8(v) shl 1
    when A is char:
      output[next] = Digits[index + 1]
      output[next - 1] = Digits[index]
    else:
      output[next] = byte(Digits[index + 1])
      output[next - 1] = byte(Digits[index])
  ok(length)

proc encode*[A: byte|char](B: typedesc[Base10], value: SomeUnsignedInt,
                           output: var openArray[A]): Result[int8, cstring] =
  ## Encode integer value to array of characters or bytes.
  B.encode(value, output, B.encodedLength(value))

proc toString*(B: typedesc[Base10], value: SomeUnsignedInt): string =
  ## Encode integer value ``value`` to string.
  var buf = newString(B.encodedLength(value))
  # Buffer of proper size is allocated, so error is not possible
  discard B.encode(value, buf, int8(len(buf)))
  buf

proc toBytes*[I: SomeUnsignedInt](B: typedesc[Base10], v: I): Base10Buf[I] {.
     noinit.} =
  ## Encode integer value ``value`` to array of bytes.
  let res = B.encode(v, result.data, B.encodedLength(v))
  result.len = int8(res.get())

proc toBytes*[I: SomeUnsignedInt](v: I, B: typedesc[Base10]): Base10Buf[I] {.
     noinit.} =
  ## Encode integer value ``value`` to array of bytes.
  let res = B.encode(v, result.data, B.encodedLength(v))
  result.len = int8(res.get())
