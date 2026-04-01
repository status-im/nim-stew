# stew
# Copyright 2019-2024 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

import std/sets, ../objects, ../templateutils

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

template keepItIf*[T](setParam: var HashSet[T], itPredicate: untyped) =
  bind evalTemplateParamOnce
  evalTemplateParamOnce(setParam, s):
    var itemsToDelete: seq[T]

    for it {.inject.} in s:
      if not itPredicate:
        itemsToDelete.add(it)

    for item in itemsToDelete:
      s.excl item

export sets, objects
