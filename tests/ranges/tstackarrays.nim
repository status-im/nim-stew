# Copyright (c) 2019-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2, math,
  ../../stew/ptrops,
  ../../stew/ranges/[stackarrays]

when (NimMajor, NimMinor) < (1, 4):
  import ../../stew/shims/stddefects

suite "Stack arrays":
  test "Basic operations work as expected":
    var arr = allocStackArray(int, 10)
    check:
      type(arr[0]) is int
      arr.len == 10

    # all items should be initially zero
    for i in arr: check i == 0
    for i in 0 .. arr.high: check arr[i] == 0

    arr[0] = 3
    arr[5] = 10
    arr[9] = 6

    check:
      sum(arr.toOpenArray) == 19
      arr[5] == 10
      arr[^1] == 6
      cast[ptr int](offset(addr arr[0], 5))[] == 10

  test "Allocating with a negative size throws a RangeError":
    expect RangeDefect:
      discard allocStackArray(string, -1)

  test "The array access is bounds-checked":
    var arr = allocStackArray(string, 3)
    arr[2] = "test"
    check arr[2] == "test"
    expect RangeDefect:
      arr[3] = "another test"

  test "proof of stack allocation":
    proc fun() =
      # NOTE: has to be inside a proc otherwise x1 not allocated on stack.
      var x1 = 0
      var arr = allocStackArray(int, 3)

      check:
        # stack can go either up or down, hence `abs`.
        # 1024 should be large enough (was 312 on OSX).
        abs(cast[int](x1.addr) - cast[int](addr(arr[0]))) < 1024
    fun()
