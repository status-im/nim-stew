# stew
# Copyright 2018-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

import std/macros, ./[assign2, enums]

export enums

template init*(lvalue: var auto) =
  mixin init
  lvalue = init(type(lvalue))

template init*(lvalue: var auto, a1: auto)=
  mixin init
  lvalue = init(type(lvalue), a1)

template init*(lvalue: var auto, a1, a2: auto) =
  mixin init
  lvalue = init(type(lvalue), a1, a2)

template init*(lvalue: var auto, a1, a2, a3: auto) =
  mixin init
  lvalue = init(type(lvalue), a1, a2, a3)

func toArray*[T](N: static int, data: openArray[T]): array[N, T] =
  doAssert data.len == N
  assign(result, data)

template anonConst*(val: untyped): untyped =
  const c = val
  c

func declval*(T: type): T {.compileTime.} =
  ## `declval` denotes an anonymous expression of a particular
  ## type. It can be used in situations where you want to determine
  ## the type of an overloaded call in `typeof` expressions.
  ##
  ## Example:
  ## ```
  ## type T = typeof foo(declval(string), declval(var int))
  ## ```
  ##
  ## Please note that `declval` has two advantages over `default`:
  ##
  ## 1. It can return expressions with proper `var` or `lent` types.
  ##
  ## 2. It will work for types that lack a valid default value due
  ##    to `not nil` or `requiresInit` requirements.
  ##
  doAssert false,
    "declval should be used only in `typeof` expressions and concepts"
  default(ptr T)[]

when not compiles(len((1, 2))):
  import typetraits

  func len*(x: tuple): int =
    arity(type(x))

# Get an object's base type, as a cstring. Ref objects will have an ":ObjectType"
# suffix.
# From: https://gist.github.com/stefantalpalaru/82dc71bb547d6f9178b916e3ed5b527d
when not defined(nimTypeNames):
  proc baseType*(obj: RootObj): cstring {.error: "baseType requires -d:nimTypeNames".}
  proc baseType*(obj: ref RootObj): cstring {.error: "baseType requires -d:nimTypeNames".}
elif defined(gcArc) or defined(gcOrc):
  proc baseType*(obj: RootObj): cstring {.error: "baseType is not available in ARC/ORC".}
  proc baseType*(obj: ref RootObj): cstring {.error: "baseType is not available in ARC/ORC".}
else:
  proc baseType*(obj: RootObj): cstring {.deprecated.} =
    {.emit: "result = `obj`->m_type->name;".}

  proc baseType*(obj: ref RootObj): cstring {.deprecated.} =
    obj[].baseType

func isZeroMemory*[T](x: T): bool =
  # TODO: iterate over words here
  # bufPtr avoids pointless https://github.com/nim-lang/Nim/issues/24093 copy
  let bufPtr = cast[ptr array[sizeof(T), byte]](unsafeAddr x)
  for b in bufPtr[]:
    if b != 0: return false
  true

func isDefaultValue*[T](x: T): bool =
  # TODO: There are ways to optimise this for simple POD types
  #       (they can be mapped to `isZeroMemory`)
  #       It may also be beneficial to store the RHS in a const.
  #       Check the codegen.
  x == default(T)
