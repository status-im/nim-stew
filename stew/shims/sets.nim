import std/sets, ../objects

when not declared(initHashSet):
  template initHashSet*[T](initialSize = 64): auto =
    initSet[T](initialSize)

template init*[T](_: type HashSet[T]): auto = initHashSet[T]()
template init*[T](_: type HashSet[T], defaultSize: int): auto = initHashSet[T](defaultSize)

# TODO: This should work, but Nim can't handle it
# template init*[T](_: type HashSet[T], args: varargs[untyped]): auto = initHashSet[T](args)

template init*[T](_: type OrderedSet[T]): auto = initOrderedSet[T]()
template init*[T](_: type OrderedSet[T], initialSize: int): auto = initOrderedSet[T](initialSize)
# template init*[T](_: type OrderedSet[T], args: varargs[untyped]): auto = initOrderedSet[T](args)

template init*[T](_: type set[T]): auto =
  var x: set[T]
  x

export sets, objects

