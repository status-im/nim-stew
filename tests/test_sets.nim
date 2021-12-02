import
  unittest,
  ../stew/shims/sets

suite "shims/sets":
  test "keepItIf":
    var s1 = init HashSet[int]
    s1.incl 10
    s1.incl 20
    s1.incl 30

    s1.keepItIf(it > 15)

    check:
      s1.len == 2
      10 notin s1
      20 in s1
      30 in s1

    var s2 = init HashSet[string]
    s2.keepItIf(it.len > 0)

    check s2.len == 0

    s2.incl "test"
    s2.keepItIf(it.len > 10)
    check s2.len == 0

    s2.incl "test"
    s2.keepItIf(it.len > 0)
    check:
      s2.len == 1
      "test" in s2
