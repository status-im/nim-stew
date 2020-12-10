import
  std/unittest,
  ../stew/assign2

suite "assign2":
  test "basic":
    type X = distinct int
    var
      a = 5
      b = [2, 3]
      c = @[5, 6]

    assign(c, b)
    check: c == b
    assign(b, [4, 5])
    check: b == [4, 5]

    assign(a, 6)
    check: a == 6

    assign(c.toOpenArray(0, 1), [2, 2])
    check: c == [2, 2]

    var
      dis = X(53)

    assign(dis, X(55))

    check: int(dis) == 55
