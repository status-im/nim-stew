# stew
# Copyright 2018-2019 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import unittest

import ../stew/ptrops

var ints = [2, 3, 4]

suite "ptrops":
  test "offset pointer":
    let
      p0: pointer = addr ints[0]
      p1: pointer = addr ints[1]
    check:
      p0.offset(sizeof(int)) == p1
      p1.offset(-sizeof(int)) == p0

  test "offset ptr":
    let
      p0 = addr ints[0]
      p1 = addr ints[1]
    check:
      p0.offset(0)[] == ints[0]
      p0.offset(1)[] == ints[1]
      p1.offset(-1)[] == ints[0]
      p0.offset(1) == p1
      p1.offset(-1) == p0

  test "offset max pointer (no overflows!)":
    check:
      cast[pointer](int.high()).offset(3) ==
        cast[pointer](cast[uint](int.high) + 3)
      cast[ptr uint16](int.high()).offset(3) ==
        cast[pointer](cast[uint](int.high) + 6)

  test "distance pointer":
    let
      p0: pointer = addr ints[0]
      p1: pointer = addr ints[2]
    check:
      p0.distance(p0) == 0
      p0.distance(p1) == sizeof(int) * 2
      p1.distance(p0) == -sizeof(int) * 2

  test "distance ptr uint16":
    let
      p0 = addr ints[0]
      p1 = addr ints[2]
    check:
      p0.distance(p0) == 0
      p0.distance(p1) == 2
      p1.distance(p0) == -2
