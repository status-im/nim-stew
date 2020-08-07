import
  unittest,
  ../stew/shims/tables

suite "tables":
  test "mgetOrPutLazy":
    var t = {"a": 10, "b": 20}.toTable
    check t.mgetOrPutLazy("a", 30) == 10
    check t.mgetOrPutLazy("c", 40) == 40

    check t.mgetOrPutLazy("c", 20) == 40

    t.mgetOrPutLazy("c", 20) = 15
    check t.mgetOrPutLazy("c", 40) == 15

