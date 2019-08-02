import std/tables, ../objects

template init*[A, B](T: type Table[A, B]): auto = initTable[A, B]()
template init*[A, B](T: type TableRef[A, B]): auto = newTable[A, B]()

template init*[A, B](T: type OrderedTable[A, B]): auto = initOrderedTable[A, B]()
template init*[A, B](T: type OrderedTableRef[A, B]): auto = newOrderedTable[A, B]()

template init*[A](T: type CountTable[A]): auto = initCountTable[A]()
template init*[A](T: type CountTableRef[A]): auto = newCountTable[A]()

export tables, objects
