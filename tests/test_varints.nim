# Copyright (c) 2019-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2, random,
  ../stew/[varints, byteutils]

const edgeValues = {
  0'u64                     : "00",
  (1'u64 shl 7) - 1'u64     : "7f",
  (1'u64 shl 7)             : "8001",
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
  uint64(1'u64 shl 63)      : "80808080808080808001",
  0xFFFF_FFFF_FFFF_FFFF'u64 : "ffffffffffffffffff01"
}

suite "varints":
  template roundtipTest(val) =
    var s {.inject.}: VarintBuffer
    s.writeVarint val

    var roundtripVal: type(val)
    let bytesRead = readVarint(s.bytes, roundtripVal)

    check:
      val == roundtripVal
      bytesRead == s.totalBytesWritten
      bytesRead == vsizeof(val)

  test "[ProtoBuf] Success edge cases test":
    for pair in edgeValues:
      let (val, hex) = pair
      roundtipTest val
      check:
        s.totalBytesWritten == hex.len div 2
        toHex(s.writtenBytes) == hex
        toHex(val.varintBytes) == hex

  test "[ProtoBuf] random 64-bit values":
    for i in 0..10000:
      # TODO nim 1.0 random casts limits to int, so anything bigger will crash
      #      * sigh *
      let v = rand(0'u64 .. cast[uint64](int.high))
      roundtipTest v

  test "[ProtoBuf] random 32-bit values":
    for i in 0..10000:
      # TODO nim 1.0 random casts limits to int, so anything bigger will crash
      #      * sigh *
      let v = rand(0'u32 .. cast[uint32](int.high))
      roundtipTest v

  # TODO Migrate the rest of the LibP2P test cases
