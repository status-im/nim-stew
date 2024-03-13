import ../stew/shims/strformat, unittest2

{.used.}

static:
  assert not compiles(fmt"{dummy}")

suite "strformat":
  test "no raises  effects":
    proc x*() {.raises: [].} =
      let str = "str"
      doAssert fmt"{str}" == "str"

    x()
