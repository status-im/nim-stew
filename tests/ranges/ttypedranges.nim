import
  unittest, sets,
  ../../stew/ranges/[typedranges, ptr_arith]

suite "Typed ranges":
  test "basic stuff":
    var r = newRange[int](5)
    r[0] = 1
    r[1 .. ^1] = [2, 3, 4, 5]

    check $r == "R[1, 2, 3, 4, 5]"

    var s = newSeq[int]()
    for a in r: s.add(a)
    check s == @[1, 2, 3, 4, 5]

  test "subrange":
    var a = newRange[int](5)
    let b = toRange(@[1, 2, 3])
    a[1 .. 3] = b
    check a.toSeq == @[0, 1, 2, 3, 0]
    check:
      a[2 .. 2].len == 1
      a[1 ..< 1].len == 0

  test "equality operator":
    var x = toRange(@[0, 1, 2, 3, 4, 5])
    var y = x[1 .. ^2]
    var z = toRange(@[1, 2, 3, 4])
    check y == z
    check x != z

  test "concat operation":
    var a = toRange(@[1,2,3])
    var b = toRange(@[4,5,6])
    var c = toRange(@[7,8,9])
    var d = @[1,2,3,4,5,6,7,8,9]
    var e = @[1,2,3,4,5,6]
    var f = @[4,5,6,7,8,9]
    var x = concat(a, b, c)
    var y = a & b
    check x == d
    check y == e
    var z = concat(b, @[7,8,9])
    check z == f

    let u = toRange(newSeq[int](0))
    let v = toRange(@[3])
    check concat(u, v) == @[3]
    check (v & u) == @[3]

  test "complex types concat operation":
    type
      Jaeger = object
        name: string
        weight: int

    var A = Jaeger(name: "Gipsy Avenger", weight: 2004)
    var B = Jaeger(name: "Striker Eureka", weight: 1850)
    var C = Jaeger(name: "Saber Athena", weight: 1628)
    var D = Jaeger(name: "Cherno Alpha", weight: 2412)

    var k = toRange(@[A, B])
    var m = toRange(@[C, D])
    var n = concat(k, m)
    check n == @[A, B, C ,D]
    check n != @[A, B, C ,C]

  test "shallowness":
    var s = @[1, 2, 3]
    var r = s.toRange()
    var r2 = r
    s[0] = 5
    check(r[0] == 5)
    s[1] = 10
    check(r2[1] == 10)
    var r3 = r[2..2]
    s[2] = 15
    check(r3[0] == 15)

  test "hash function":
    var a = toRange(@[1,2,3])
    var b = toRange(@[4,5,6])
    var c = toRange(@[7,8,9])
    var d = toRange(@[1,2,3,4,5,6,7,8,9])
    var e = toRange(@[1,2,3,4,5,6,7,8,9])
    var x = toHashSet([a, b, c, a, b])
    check x.len == 3
    check a in x

    var z = toRange(@[7,8,9])
    var y = toHashSet([z, b, c])
    check z in y
    check z in x

    var u = d[0..2]
    var v = d[3..5]
    var uu = e[0..2]
    var vv = e[3..5]
    check hash(u) != hash(v)
    check hash(uu) == hash(u)
    check hash(v) == hash(vv)
    check hash(uu) != hash(vv)

  test "toOpenArray":
    var a = toRange(@[1,2,3])
    check $a.toOpenArray == "[1, 2, 3]"

  test "MutRange[T] shallow test":
    var b = @[1, 2, 3, 4, 5, 6]
    var r1 = b.toRange()
    var r2 = r1
    b[0] = 5
    b[1] = 10
    b[2] = 15
    var r3 = r1[1..1]
    var a0 = cast[uint](addr b[0])
    var a1 = cast[uint](r1.gcHolder)
    var a2 = cast[uint](r2.gcHolder)
    var a3 = cast[uint](r3.gcHolder)
    check:
      a1 == a0
      a2 == a0
      a3 == a0

  test "Range[T] shallow test":
    var r1 = toRange(@[1, 2, 3, 4, 5, 6])
    var r2 = r1
    var r3 = r1[1..1]
    var a1 = cast[uint](r1.gcHolder)
    var a2 = cast[uint](r2.gcHolder)
    var a3 = cast[uint](r3.gcHolder)
    check:
      a2 == a1
      a3 == a1

  test "tryAdvance(Range)":
    var a: Range[int]
    check:
      a.tryAdvance(1) == false
      a.tryAdvance(-1) == false
      a.tryAdvance(0) == true
    var b = toRange(@[1, 2, 3])
    check:
      b.tryAdvance(-1) == false
      $b.toOpenArray == "[1, 2, 3]"
      b.tryAdvance(0) == true
      $b.toOpenArray == "[1, 2, 3]"
      b.tryAdvance(1) == true
      $b.toOpenArray == "[2, 3]"
      b.tryAdvance(1) == true
      $b.toOpenArray == "[3]"
      b.tryAdvance(1) == true
      $b.toOpenArray == "[]"
      b.tryAdvance(1) == false
      $b.toOpenArray == "[]"

  test "advance(Range)":
    template aecheck(a, b): int =
      var res = 0
      try:
        a.advance(b)
        res = 1
      except IndexError:
        res = 2
      res

    var a: Range[int]
    check:
      a.aecheck(1) == 2
      a.aecheck(-1) == 2
      a.aecheck(0) == 1
    var b = toRange(@[1, 2, 3])
    check:
      b.aecheck(-1) == 2
      $b.toOpenArray == "[1, 2, 3]"
      b.aecheck(0) == 1
      $b.toOpenArray == "[1, 2, 3]"
      b.aecheck(1) == 1
      $b.toOpenArray == "[2, 3]"
      b.aecheck(1) == 1
      $b.toOpenArray == "[3]"
      b.aecheck(1) == 1
      $b.toOpenArray == "[]"
      b.aecheck(1) == 2
      $b.toOpenArray == "[]"

  test "tryAdvance(MutRange)":
    var a: MutRange[int]
    check:
      a.tryAdvance(1) == false
      a.tryAdvance(-1) == false
      a.tryAdvance(0) == true
    var buf = @[1, 2, 3]
    var b = toRange(buf)
    check:
      b.tryAdvance(-1) == false
      $b.toOpenArray == "[1, 2, 3]"
      b.tryAdvance(0) == true
      $b.toOpenArray == "[1, 2, 3]"
      b.tryAdvance(1) == true
      $b.toOpenArray == "[2, 3]"
      b.tryAdvance(1) == true
      $b.toOpenArray == "[3]"
      b.tryAdvance(1) == true
      $b.toOpenArray == "[]"
      b.tryAdvance(1) == false
      $b.toOpenArray == "[]"

  test "advance(MutRange)":
    template aecheck(a, b): int =
      var res = 0
      try:
        a.advance(b)
        res = 1
      except IndexError:
        res = 2
      res

    var a: MutRange[int]
    check:
      a.aecheck(1) == 2
      a.aecheck(-1) == 2
      a.aecheck(0) == 1
    var buf = @[1, 2, 3]
    var b = toRange(buf)
    check:
      b.aecheck(-1) == 2
      $b.toOpenArray == "[1, 2, 3]"
      b.aecheck(0) == 1
      $b.toOpenArray == "[1, 2, 3]"
      b.aecheck(1) == 1
      $b.toOpenArray == "[2, 3]"
      b.aecheck(1) == 1
      $b.toOpenArray == "[3]"
      b.aecheck(1) == 1
      $b.toOpenArray == "[]"
      b.aecheck(1) == 2
      $b.toOpenArray == "[]"

  test "make openarrays from pointers":
    var str = "test 1,2,3"
    var charPtr: ptr char = addr str[7]
    var regularPtr: pointer = addr str[5]

    check:
      # (regularPtr.makeOpenArray(char, 4).len == 4)
      (regularPtr.makeOpenArray(char, 5) == "1,2,3")
      (regularPtr.makeOpenArray(char, 5) == str[5..9])

      # (charPtr.makeOpenArray(3).len == 3)
      (charPtr.makeOpenArray(3) == "2,3")
      (charPtr.makeOpenArray(1) == str[7..7])

