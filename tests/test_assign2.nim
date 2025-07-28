# Copyright (c) 2020-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2,
  ../stew/assign2

proc makeCopy(a: array[2, byte]): array[2, byte] =
  assign(result, a)

suite "assign2":
  dualTest "basic":
    type X = distinct int
    var
      a = 5
      b = [2, 3]
      c = @[5, 6]
      d = "hello"

    assign(c, b)
    check: c == b
    assign(b, [4, 5])
    check: b == [4, 5]

    assign(a, 6)
    check: a == 6

    assign(c.toOpenArray(0, 1), [2, 2])
    check: c == [2, 2]

    assign(d, "there!")
    check: d == "there!"

    when (NimMajor, NimMinor) >= (2, 0):
      var dis = X(53)

      assign(dis, X(55))

      check: int(dis) == 55

      const x = makeCopy([byte 0, 2]) # compile-time evaluation
      check x[1] == 2

  test "Overlaps":
    when (NimMajor, NimMinor) >= (2, 0):
      # This does not work correctly at compile time
      var s = @[byte 0, 1, 2, 3, 0, 0, 0, 0]
      assign(s.toOpenArray(1, s.high), s.toOpenArray(0, s.high - 1))
      check:
        s == [byte 0, 0, 1, 2, 3, 0, 0, 0]
