import
  unittest2, typetraits,
  ../stew/objects

when defined(nimHasUsed):
  {.used.}

{.experimental: "notnil".}

suite "Objects":
  test "baseType":
    type
      Foo = ref object of RootObj
      Bar = ref object of Foo
      Baz = object of RootObj
      Bob = object of Baz
      Bill = ref object of Bob

    var
      foo = Foo()
      bar = Bar()
      baz = Baz()
      bob = Bob()
      bill = Bill()

    when defined(nimTypeNames):
      check:
        foo.baseType == "Foo:ObjectType"
        bar.baseType == "Bar:ObjectType"
        baz.baseType == "Baz"
        bob.baseType == "Bob"
        bill.baseType == "Bill:ObjectType"

      proc f(o: Foo) =
        check $o.type == "Foo"
        check o.baseType == "Bar:ObjectType"

      f(bar)

  test "declval":
    type
      Bar = object
        x: RootRef not nil

      DistinctBar = distinct Bar

    proc foo(x: int): string =
      discard

    proc foo(x: var int): float =
      discard

    proc foo(x: Bar): int =
      discard

    type
      T1 = typeof foo(declval(int))
      T2 = typeof foo(declval(var int))
      T3 = typeof foo(declval(lent int))
      T4 = typeof foo(declval(Bar))
      T5 = typeof foo(declval(var Bar))
      T6 = typeof declval(DistinctBar)

    check:
      T1 is string
      T2 is float
      T3 is string
      T4 is int
      T5 is int
      T6 is DistinctBar
      T6 isnot Bar

  test "enumRangeInt64":
    type
      WithoutHoles = enum
        A1, A2, A3
      WithoutHoles2 = enum
        B1 = 4, B2 = 5, B3 = 6
      WithHoles = enum
        C1 = 1, C2 = 3, C3 = 5

    check:
      enumRangeInt64(WithoutHoles) == [ 0'i64, 1, 2 ]
      enumRangeInt64(WithoutHoles2) == [ 4'i64, 5, 6 ]
      enumRangeInt64(WithHoles) == [ 1'i64, 3, 5 ]


  test "contains":
    type
      WithoutHoles = enum
        A1, A2, A3
      WithoutHoles2 = enum
        B1 = 4, B2 = 5, B3 = 6
      WithHoles = enum
        C1 = 1, C2 = 3, C3 = 5
      WithoutHoles3 = enum
        D1 = -1, D2 = 0, D3 = 1
      WithHoles2 = enum
        E1 = -5, E2 = 0, E3 = 5

    check:
      1 in WithoutHoles
      5 notin WithoutHoles
      1 notin WithoutHoles2
      5 in WithoutHoles2
      1 in WithHoles
      2 notin WithHoles
      6 notin WithHoles
      5 in WithHoles
      1.byte in WithoutHoles
      4294967295'u32 notin WithoutHoles3
      -1.int8 in WithoutHoles3
      -4.int16 notin WithoutHoles3
      -5.int16 in WithHoles2
      5.uint64 in WithHoles2
      -12.int8 notin WithHoles2
      int64.high notin WithoutHoles
      int64.high notin WithHoles
      int64.low notin WithoutHoles
      int64.low notin WithHoles
      int64.high.uint64 * 2 notin WithoutHoles
      int64.high.uint64 * 2 notin WithHoles


  test "hasHoles":
    type
      EnumWithOneValue = enum
        A0

      WithoutHoles = enum
        A1, B1, C1

      WithoutHoles2 = enum
        A2 = 2, B2 = 3, C2 = 4

      WithHoles = enum
        A3, B3 = 2, C3

      WithBigHoles = enum
        A4 = 0, B4 = 2000, C4 = 4000

    check:
      hasHoles(EnumWithOneValue) == false
      hasHoles(WithoutHoles) == false
      hasHoles(WithoutHoles2) == false
      hasHoles(WithHoles) == true
      hasHoles(WithBigHoles) == true

  test "checkedEnumAssign":
    type
      SomeEnum = enum
        A1, B1, C1

      AnotherEnum = enum
        A2 = 2, B2, C2

      EnumWithHoles = enum
        A3, B3 = 3, C3
    var
      e1 = A1
      e2 = A2
      e3 = A3

    check:
      checkedEnumAssign(e1, 2)
      e1 == C1
      not checkedEnumAssign(e1, 5)
      e1 == C1
      checkedEnumAssign(e1, 0)
      e1 == A1
      not checkedEnumAssign(e1, -1)
      e1 == A1

      checkedEnumAssign(e2, 2)
      e2 == A2
      not checkedEnumAssign(e2, 5)
      e2 == A2
      checkedEnumAssign(e2, 4)
      e2 == C2
      not checkedEnumAssign(e2, 1)
      e2 == C2

      checkedEnumAssign(e3, 4)
      e3 == C3
      not checkedEnumAssign(e3, 1)
      e3 == C3
      checkedEnumAssign(e3, 0)
      e3 == A3
      not checkedEnumAssign(e3, -1)
      e3 == A3

  test "isZeroMemory":
    type
      Foo = object
        x: string
        y: int
      FooRef = ref Foo
      Bar = object of RootObj
      Baz = ref object of Bar

    var
      z0 = 0
      z1: int
      z2: FooRef
      z3: Foo
      z4: FooRef
      z5: uint8
      z6: array[10, int]
      z7: array[10, Foo]
      z8: string
      z9: float
      z10: seq[int]
      z11: seq[Bar]
      z12: Baz

    check:
      isZeroMemory z0
      isZeroMemory z1
      isZeroMemory z2
      isZeroMemory z3
      isZeroMemory z4
      isZeroMemory z5
      isZeroMemory z6
      isZeroMemory z7
      isZeroMemory z8
      isZeroMemory z9
      isZeroMemory z10
      isZeroMemory z11
      isZeroMemory z12

    var
      nz0 = 1
      nz1: int = -100
      nz2 = FooRef()
      nz3 = Foo(y: 10)
      nz4: Bar
      nz5 = Baz()
      nz6 = [1, 2, 3]
      nz7 = [Foo(y: 20), Foo(y: 10)]
      nz8 = "test"
      nz9 = 1.23
      nz10 = @[1, 2, 3]

    check:
      not isZeroMemory nz0
      not isZeroMemory nz1
      not isZeroMemory nz2
      not isZeroMemory nz3
      not isZeroMemory nz4
      not isZeroMemory nz5
      not isZeroMemory nz6
      not isZeroMemory nz7
      not isZeroMemory nz8
      not isZeroMemory nz9
      not isZeroMemory nz10
