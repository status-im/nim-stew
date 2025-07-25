# stew
# Copyright 2018-2022 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import unittest2

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

  test "baseAddr":
    block arrays:
      var
        v0: array[0, int] = []
        v1 = [22]

      check:
        baseAddr(v0) == nil
        baseAddr(v1) == addr v1[0]
        baseAddr(v1)[] == v1[0]

    block seqs:
      var
        v0: seq[int]
        v1 = @[22]

      check:
        baseAddr(v0) == nil
        baseAddr(v1) == addr v1[0]
        baseAddr(v1)[] == v1[0]

    block oas:
      var v = 56
      check:
        baseAddr(makeOpenArray(nil, int, 0)) == nil
        baseAddr(makeOpenArray(addr v, 1)) == addr v

    block ua:
      var v = [2, 3]
      check:
        makeUncheckedArray(baseAddr v)[1] == 3

  test "var makeOpenArray":
    # fixed in 2.0.10+: https://github.com/nim-lang/Nim/pull/23882
    proc takesVar(v: var openArray[byte]) = discard
    var tmp: byte
    check compiles(takesVar(makeOpenArray(addr tmp, 1)))
