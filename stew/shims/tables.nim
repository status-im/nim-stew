import std/tables, ../objects

template init*[A, B](T: type Table[A, B]): auto = initTable[A, B]()
template init*[A, B](T: type TableRef[A, B]): auto = newTable[A, B]()

template init*[A, B](T: type OrderedTable[A, B]): auto = initOrderedTable[A, B]()
template init*[A, B](T: type OrderedTableRef[A, B]): auto = newOrderedTable[A, B]()

template init*[A](T: type CountTable[A]): auto = initCountTable[A]()
template init*[A](T: type CountTableRef[A]): auto = newCountTable[A]()

template mgetOrPutLazy*[A, B](t: Table[A, B], key: A, val: B): var B =
  type R = B

  proc setter(loc: var R): var R =
    if loc == default(R):
      loc = val
    loc

  setter(mgetOrPut(t, key, default(R)))

export tables, objects

