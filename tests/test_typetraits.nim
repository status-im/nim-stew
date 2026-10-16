# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import unittest2, ../stew/shims/typetraits

type
  Kind = enum
    kindA
    kindB

  PlainObject = object
    a: int
    b: ptr string

  StringObject = object
    s: string

  ScalarCaseObject = object
    case kind: Kind
    of kindA:
      a: int
    of kindB:
      b: float

  CaseObject = object
    case kind: Kind
    of kindA:
      a: int
    of kindB:
      b: seq[int]

  BaseObject = object of RootObj
    base: int

  DerivedObject = object of BaseObject
    derived: int

  StringBaseObject = object of RootObj
    s: string

  DerivedFromStringBase = object of StringBaseObject
    derived: int

  RefObject = ref object
    a: int

  GenericObject[T] = object
    value: T

  GenericSeq[T] = seq[T]
  GenericArray[T] = array[2, T]
  GenericDistinct[T] = distinct T

  MoveOnlyObject = object
    data: ptr UncheckedArray[byte]

func `=copy`(dest: var MoveOnlyObject, source: MoveOnlyObject) {.error.}

template genericObjectOf(T: type): untyped = GenericObject[T]

type
  TemplateCallAlias = genericObjectOf(string)
  TypeofAlias = typeof(default(GenericObject[int]))

func topLevelFunc() =
  discard

suite "typetraits":
  test "supportsSharedMem":
    check:
      supportsSharedMem(int)
      supportsSharedMem(cstring)
      supportsSharedMem(Kind)
      supportsSharedMem(range[0 .. 3])
      supportsSharedMem(set[Kind])
      supportsSharedMem(ptr string)
      supportsSharedMem(ptr UncheckedArray[string])
      supportsSharedMem(proc() {.nimcall.})
      supportsSharedMem(proc(x: int) {.cdecl, raises: [].})
      supportsSharedMem(typeof(topLevelFunc))
      supportsSharedMem(sink int)
      supportsSharedMem(array[2, int])
      supportsSharedMem(GenericArray[int])
      supportsSharedMem(GenericDistinct[int])
      supportsSharedMem(MoveOnlyObject)
      supportsSharedMem(PlainObject)
      supportsSharedMem(ScalarCaseObject)
      supportsSharedMem(DerivedObject)
      supportsSharedMem(GenericObject[int])
      supportsSharedMem(TypeofAlias)
      supportsSharedMem((int, PlainObject))
      supportsSharedMem(tuple[a: int, b: float])
      not supportsSharedMem(string)
      not supportsSharedMem(seq[int])
      not supportsSharedMem(GenericSeq[int])
      not supportsSharedMem(ref int)
      not supportsSharedMem(RefObject)
      not supportsSharedMem(StringObject)
      not supportsSharedMem(CaseObject)
      not supportsSharedMem(DerivedFromStringBase)
      not supportsSharedMem(GenericObject[string])
      not supportsSharedMem(TemplateCallAlias)
      not supportsSharedMem(proc())
      not supportsSharedMem(proc(x: int) {.gcsafe, raises: [].})
      not supportsSharedMem(iterator(): int)
      not supportsSharedMem(sink seq[int])
      not supportsSharedMem(UncheckedArray[string])
      not supportsSharedMem(array[2, string])
      not supportsSharedMem(GenericArray[string])
      not supportsSharedMem(GenericDistinct[GenericDistinct[string]])
      not supportsSharedMem((int, string))
      not supportsSharedMem(tuple[a: int, b: seq[int]])
      not supportsSharedMem(array[2, (int, string)])
