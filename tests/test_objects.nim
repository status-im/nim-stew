import
  unittest2, typetraits,
  ../stew/objects

{.used.}
{.experimental: "notnil".}

template isZeroAndDefault(x: auto): bool =
  isZeroMemory(x) and isDefaultValue(x)

suite "Objects":
  test "baseType":
    when (not defined(nimTypeNames)) or defined(gcOrc) or defined(gcArc):
      skip()
      return
    else:
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

  test "isZeroMemory/isDefaultValue":
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
      isZeroAndDefault z0
      isZeroAndDefault z1
      isZeroAndDefault z2
      isZeroAndDefault z3
      isZeroAndDefault z4
      isZeroAndDefault z5
      isZeroAndDefault z6
      isZeroAndDefault z7
      isZeroAndDefault z8
      isZeroAndDefault z9
      isZeroAndDefault z10
      isZeroAndDefault z11
      isZeroAndDefault z12

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
      not isZeroAndDefault nz0
      not isZeroAndDefault nz1
      not isZeroAndDefault nz2
      not isZeroAndDefault nz3
      not isZeroAndDefault nz4
      not isZeroAndDefault nz5
      not isZeroAndDefault nz6
      not isZeroAndDefault nz7
      not isZeroAndDefault nz8
      not isZeroAndDefault nz9
      not isZeroAndDefault nz10
