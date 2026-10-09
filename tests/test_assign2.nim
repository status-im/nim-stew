# Copyright (c) 2020-2026 Status Research & Development GmbH
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
    type
      X = distinct int
      Y = object
        case kind: bool
        of false:
          f: uint8
        of true:
          t: seq[int]
      Base[T] = object of RootObj
        base: T
      Z[T] = object of Base[seq[T]]
        case kind: bool
        of false:
          f: T
        of true:
          case nested: bool
          of false:
            discard
          of true:
            t: seq[T]
      V = object
        case a: range[0..2]
        of 0:
          f: uint8
        of 1, 2:
          t: seq[int]
        case b: char
        of 'x':
          s: string
        else:
          discard
      U = distinct uint8
      W = object
        case kind: U
        of U(0):
          f: uint8
        else:
          t: seq[int]
    var
      a = 5
      b = [2, 3]
      c = @[5, 6]
      d = "hello"
      e = [@[7], @[8, 9]]

    assign(c, b)
    check: c == b
    assign(b, [4, 5])
    check: b == [4, 5]
    assign(e, [@[1], @[2, 3]])
    check: e == [@[1], @[2, 3]]

    assign(a, 6)
    check: a == 6

    assign(c.toOpenArray(0, 1), [2, 2])
    check: c == [2, 2]

    assign(d, "there!")
    check: d == "there!"

    var dis = X(53)
    assign(dis, X(55))
    check: int(dis) == 55

    var obj = Y(kind: true, t: @[2])
    for value in [Y(kind: false, f: 3), Y(kind: true, t: @[4, 5]),
        Y(kind: true, t: @[6])]:
      assign(obj, value)
      check: $obj == $value

    var gen = Z[int](base: @[1], kind: true, nested: true, t: @[2])
    for value in [Z[int](base: @[3], kind: false, f: 4),
        Z[int](base: @[5], kind: true, nested: true, t: @[6]),
        Z[int](base: @[7], kind: true, nested: false)]:
      assign(gen, value)
      check: $gen == $value

    var sib = V(a: 1, t: @[2], b: 'y')
    for value in [V(a: 0, f: 3, b: 'x', s: "4"),
        V(a: 2, t: @[5], b: 'x', s: "6"), V(a: 1, t: @[7], b: 'y')]:
      assign(sib, value)
      check: $sib == $value

    var tag = W(kind: U(1), t: @[2])
    for value in [W(kind: U(0), f: 3), W(kind: U(2), t: @[4]),
        W(kind: U(1), t: @[5])]:
      assign(tag, value)
      check:
        uint8(tag.kind) == uint8(value.kind)
        $tag == $value

    const x = makeCopy([byte 0, 2]) # compile-time evaluation
    check x[1] == 2

  test "Overlaps":
    # This does not work correctly at compile time
    var s = @[byte 0, 1, 2, 3, 0, 0, 0, 0]
    assign(s.toOpenArray(1, s.high), s.toOpenArray(0, s.high - 1))
    check:
      s == [byte 0, 0, 1, 2, 3, 0, 0, 0]
