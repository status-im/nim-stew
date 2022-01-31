import
  unittest, typetraits,
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

  when false:
    # TODO: Not possible yet (see objects.nim)
    test "hasHoles":
      type
        WithoutHoles = enum
          A1, B1, C1

        WithoutHoles2 = enum
          A2 = 2, B2 = 3, C2 = 4

        WithHoles = enum
          A3, B3 = 2, C3

      check:
        hasHoles(WithoutHoles2) == false
        hasHoles(WithoutHoles) == false
        hasHoles(WithHoles) == true

  test "checkedEnumAssign":
    type
      SomeEnum = enum
        A1, B1, C1

      AnotherEnum = enum
        A2 = 2, B2, C2

    var
      e1 = A1
      e2 = A2

    check:
      checkedEnumAssign(e1, 2)
      e1 == C1

    check:
      not checkedEnumAssign(e1, 5)
      e1 == C1

    check:
      checkedEnumAssign(e1, 0)
      e1 == A1

    check:
      not checkedEnumAssign(e1, -1)
      e1 == A1

    check:
      checkedEnumAssign(e2, 2)
      e2 == A2

    check:
      not checkedEnumAssign(e2, 5)
      e2 == A2

    check:
      checkedEnumAssign(e2, 4)
      e2 == C2

    check:
      not checkedEnumAssign(e2, 1)
      e2 == C2

  test "isZeroMemory and isDefault":
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
      isDefault z0
      isDefault z1
      isDefault z2
      isDefault z3
      isDefault z4
      isDefault z5
      isDefault z6
      isDefault z7
      isDefault z8
      isDefault z9
      isDefault z10
      isDefault z11
      isDefault z12

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
      not isDefault nz0
      not isDefault nz1
      not isDefault nz2
      not isDefault nz3
      not isDefault nz4
      not isDefault nz5
      not isDefault nz6
      not isDefault nz7
      not isDefault nz8
      not isDefault nz9
      not isDefault nz10
