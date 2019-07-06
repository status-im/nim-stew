import tables, objects

template init*[A, B](T: type Table[A, B]): auto = initTable[A, B]()

export tables, objects
