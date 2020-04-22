import
  unittest, typetraits,
  ../stew/objects

when defined(nimHasUsed):
  {.used.}

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
    proc foo(x: int): string =
      discard

    proc foo(x: var int): float =
      discard

    type
      T1 = typeof foo(declval(int))
      T2 = typeof foo(declval(var int))
      T3 = typeof foo(declval(lent int))

    check:
      T1 is string
      T2 is float
      T3 is string

