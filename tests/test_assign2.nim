# Copyright (c) 2020-2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  std/tables,
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

    const x = makeCopy([byte 0, 2]) # compile-time evaluation
    check x[1] == 2

    var
      a2 = 7
      b2 = [8, 9]
      c2 = @[10]
      d2 = "moved"
      e2 = [@[11], @[12, 13]]
      dis2 = X(57)

    a.moveAssign(a2)
    check: a == 7 and a2 == 0
    b.moveAssign(b2)
    check: b == [8, 9] and b2 == [0, 0]
    c.moveAssign(c2)
    check: c == [10] and c2.len == 0
    d.moveAssign(d2)
    check: d == "moved" and d2.len == 0
    e.moveAssign(e2)
    check: e == [@[11], @[12, 13]] and e2[0].len == 0 and e2[1].len == 0
    dis.moveAssign(dis2)
    check: int(dis) == 57 and int(dis2) == 0

    proc moveTagged(tgt, src: var seq[int]) {.tags: [].} =
      tgt.moveAssign(src)

    moveTagged(c2, c)
    check: c2 == [10] and c.len == 0

  dualTest "case objects":
    type
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
      R = object
        y: Y
        s: string

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

    for value in [
        Y(kind: false, f: 3),
        Y(kind: true, t: @[4, 5]),
        Y(kind: true, t: @[6])]:
      var src = value
      obj.moveAssign(src)
      check:
        $obj == $value
        $src == $Y()

    for value in [
        Z[int](base: @[3], kind: false, f: 4),
        Z[int](base: @[5], kind: true, nested: true, t: @[6]),
        Z[int](base: @[7], kind: true, nested: false)]:
      var src = value
      gen.moveAssign(src)
      check:
        $gen == $value
        $src == $Z[int]()

    for value in [
        V(a: 0, f: 3, b: 'x', s: "4"),
        V(a: 2, t: @[5], b: 'x', s: "6"),
        V(a: 1, t: @[7], b: 'y')]:
      var src = value
      sib.moveAssign(src)
      check:
        $sib == $value
        $src == $V()

    for value in [
        W(kind: U(0), f: 3),
        W(kind: U(2), t: @[4]),
        W(kind: U(1), t: @[5])]:
      var src = value
      tag.moveAssign(src)
      check:
        uint8(tag.kind) == uint8(value.kind)
        $tag == $value
        uint8(src.kind) == 0
        $src == $W()

    var
      tgt = R(y: Y(kind: false, f: 4), s: "5")
      src = R(y: Y(kind: true, t: @[2]), s: "3")
    tgt.moveAssign(src)
    check:
      tgt.y.kind and tgt.y.t == @[2] and tgt.s == "3"
      not src.y.kind and src.y.f == 0 and src.s.len == 0

  test "Overlaps":
    # This does not work correctly at compile time
    var s = @[byte 0, 1, 2, 3, 0, 0, 0, 0]
    assign(s.toOpenArray(1, s.high), s.toOpenArray(0, s.high - 1))
    check:
      s == [byte 0, 0, 1, 2, 3, 0, 0, 0]

    # A location cannot be moved into itself
    expect(AssertionDefect):
      s.moveAssign(s)
    check:
      s == [byte 0, 0, 1, 2, 3, 0, 0, 0]

  test "Unsupported types":
    template supported(T: type): bool =
      compiles:
        var a, b: T
        a.moveAssign(b)

    type
      Kind = enum
        kindA
        kindB
      Leaf = object
        number: int
        list: seq[string]
      Wrapped = distinct Leaf
      Generic[T; N: static int] = object
        items: array[N, T]
        list: seq[T]
      List[T; N: static int] = distinct seq[T]
      Variant = object
        case kind: Kind
        of kindA:
          number: uint8
        of kindB:
          generic: Generic[Wrapped, 2]
      Parent = object of RootObj
        list: List[Leaf, 4]
      Child = object of Parent
        variant: Variant
      Plain = object
        child: Child
        pair: tuple[a: int, b: seq[Leaf]]
        anonymous: (int, string)
        table: Table[string, seq[Child]]
        borrowed: ptr Leaf
        many: ptr UncheckedArray[Leaf]
        text: cstring
        flags: set[Kind]
        small: range[0 .. 5]
        byKind: array[Kind, Leaf]

      ViaRef = object
        next: ref ViaRef
      ViaSeq = object
        children: seq[ViaSeq]
      ViaBranch = object
        case kind: Kind
        of kindA:
          discard
        of kindB:
          children: seq[ViaBranch]
      ViaParent = object of RootObj
        children: seq[ViaChild]
      ViaChild = object of ViaParent
      ViaGeneric = object
        generic: Generic[seq[ViaGeneric], 2]
      ViaTuple = object
        pair: tuple[a: int, b: seq[ViaTuple]]
      ViaDistinct = object
        list: List[ViaDistinct, 2]
      First = object
        second: seq[Second]
      Second = object
        first: seq[First]
      WithClosure = object
        callback: proc ()
      NoHooks = object
        data: pointer
        callback: proc () {.nimcall.}

    check:
      supported(int)
      supported(string)
      supported(seq[seq[int]])
      supported(Leaf)
      supported(Wrapped)
      supported(Generic[Leaf, 3])
      supported(List[Wrapped, 3])
      supported(Variant)
      supported(Parent)
      supported(Child)
      supported(Plain)
      supported(NoHooks)

      not supported(ViaRef)
      not supported(ViaSeq)
      not supported(ViaBranch)
      not supported(ViaParent)
      not supported(ViaChild)
      not supported(ViaGeneric)
      not supported(ViaTuple)
      not supported(ViaDistinct)
      not supported(First)
      not supported(Second)
      not supported(WithClosure)
      not supported(seq[ViaSeq])

    block:
      # Same name as the supported `Leaf` above, but a different type
      type Leaf = object
        next: ref Leaf
      check not supported(Leaf)

  test "Large objects":
    # Too large for a temporary copy on the stack
    type
      Plain = array[16 * 1024 * 1024, byte]
      PlainCase = object
        case kind: bool
        of false:
          f: uint8
        of true:
          t: Plain
      Huge = object
        data: Plain
        list: seq[int]
      HugeCase = object
        case kind: bool
        of false:
          f: seq[int]
        of true:
          t: Huge

    let
      a = new Plain
      b = new Plain
    b[^1] = 1
    a[].moveAssign(b[])
    check: a[^1] == 1 and b[^1] == 0

    let
      c = (ref PlainCase)(kind: false, f: 2)
      d = (ref PlainCase)(kind: true)
    d.t[^1] = 3
    c[].moveAssign(d[])
    check:
      c.kind and c.t[^1] == 3
      not d.kind and d.f == 0

    let
      e = new Huge
      f = new Huge
    e.list = @[4]
    f.data[0] = 5
    f.data[^1] = 6
    f.list = @[7, 8]
    e[].moveAssign(f[])
    check:
      e.data[0] == 5 and e.data[^1] == 6 and e.list == @[7, 8]
      f.data[0] == 0 and f.data[^1] == 0 and f.list.len == 0

    let
      g = (ref HugeCase)(kind: false, f: @[9])
      h = (ref HugeCase)(kind: true)
    h.t.data[^1] = 10
    h.t.list = @[11]
    g[].moveAssign(h[])
    check:
      g.kind and g.t.data[^1] == 10 and g.t.list == @[11]
      not h.kind and h.f.len == 0
