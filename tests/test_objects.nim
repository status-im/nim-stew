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

    check:
      T1 is string
      T2 is float
      T3 is string
      T4 is int
      T5 is int

