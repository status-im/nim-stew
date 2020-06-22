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

