# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import unittest2, ../stew/shims/iterators

from ./test_macros_helpers import HelperBaseType

const elseOfKinds = {1, 2}

type
  MyType[T] = object
    myField: string
    myGeneric: T
    case kind: bool
      of true:
        first: string
      else:
        second: string

  FieldKind = enum
    kindA
    kindB

  BaseType = object of RootObj
    baseField: int
    case baseCaseField: FieldKind
    of kindA:
      baseA: int
    of kindB:
      discard

  DerivedType = ref object of BaseType
    derivedField: int

  DerivedFromRefType = ref object of DerivedType
    anotherDerivedField: string

  DerivedFromHelperType = object of HelperBaseType
    helperDerivedField: int

  GenericBaseType[T] = object of RootObj
    genericBaseField: T

  PtrType = ptr object of GenericBaseType[int]
    ptrField: int

  StaticType[N: static int] = object
    staticField: array[N, byte]
    when N > 1:
      staticWhenField: int

  NestedCaseType = object
    case outerKind: FieldKind
    of kindA, kindB:
      case innerKind: range[0 .. 3]
      of 1 .. 2:
        nestedField: int
      else:
        discard

  ElseCaseType = object
    case elseKind: range[0 .. 3]
    of elseOfKinds:
      elseOfField: int
    of 3:
      discard
    else:
      elseField: int
    case elseOnlyKind: bool
    else:
      elseOnlyField: int

  QuotedType = object
    `quoted field`: int
    `type`: int
    case `quoted kind`: bool
    of true:
      quotedBranch: int
    of false:
      discard

  RequiresInitType {.requiresInit.} = object
    requiresInitField: int

  TupleType = tuple[tupleField: int]
  UnnamedTupleType = (int, string)
  RefPtrUnnamedTupleType = ref ptr UnnamedTupleType

  EmptyObject = object

func typeParamFieldTypePairsList(T: type): seq[string] =
  var res: seq[string]
  for name, FieldType in fieldTypePairs(T):
    res.add name & ": " & $FieldType
  res

func typeParamFieldNamesList(T: type): seq[string] =
  var res: seq[string]
  for name, _ in fieldTypePairs(T):
    res.add name
  res

func typeParamFieldTypesCount(T: type): int =
  var res = 0
  for _, _ in fieldTypePairs(T):
    inc res
  res

template getFieldTypePairsList(T: type): untyped =
  block:
    var res, names: seq[string]
    for name, FieldType in fieldTypePairs(T):
      res.add name & ": " & $FieldType
      names.add name
    doAssert typeParamFieldTypePairsList(T) == res
    doAssert typeParamFieldTypePairsList(sink T) == res
    doAssert typeParamFieldNamesList(T) == names
    doAssert typeParamFieldTypesCount(T) == res.len
    res

template checkFieldTypePairs(T: type, expected: openArray[string]) =
  static: doAssert getFieldTypePairsList(T) == @expected
  check getFieldTypePairsList(T) == @expected

func namesBeforeKind(): seq[string] =
  var names: seq[string]
  for name, _ in fieldTypePairs(MyType[string]):
    if name == "kind":
      break
    names.add name
  names

func namesBeforeKindViaTemplate(): seq[string] =
  template stop() = break
  var names: seq[string]
  for name, _ in fieldTypePairs(MyType[string]):
    if name == "kind":
      stop()
    names.add name
  names

suite "iterators":
  test "fieldTypePairs":
    checkFieldTypePairs(MyType[string], [
      "myField: string",
      "myGeneric: string",
      "kind: bool",
      "second: string"
    ])

    checkFieldTypePairs(DerivedFromRefType, [
      "anotherDerivedField: string",
      "derivedField: int",
      "baseField: int",
      "baseCaseField: FieldKind",
      "baseA: int"
    ])

    checkFieldTypePairs(DerivedFromHelperType, [
      "helperDerivedField: int",
      "helperBaseField: int",
      "helperPrivateField: int"
    ])

    checkFieldTypePairs(PtrType, [
      "ptrField: int",
      "genericBaseField: int"
    ])

    checkFieldTypePairs(StaticType[2], [
      "staticField: array[0..1, byte]",
      "staticWhenField: int"
    ])

    checkFieldTypePairs(NestedCaseType, [
      "outerKind: FieldKind",
      "innerKind: range 0..3(int)"
    ])

    checkFieldTypePairs(ElseCaseType, [
      "elseKind: range 0..3(int)",
      "elseField: int",
      "elseOnlyKind: bool",
      "elseOnlyField: int"
    ])

    checkFieldTypePairs(QuotedType, [
      "quotedfield: int",
      "type: int",
      "quotedkind: bool"
    ])

    checkFieldTypePairs(RequiresInitType, [
      "requiresInitField: int"
    ])

    checkFieldTypePairs(TupleType, [
      "tupleField: int"
    ])

    checkFieldTypePairs(RefPtrUnnamedTupleType, [
      "Field0: int",
      "Field1: string"
    ])

    checkFieldTypePairs(EmptyObject, array[0, string]([]))

  test "fieldTypePairs control flow":
    static:
      doAssert namesBeforeKind() == @["myField", "myGeneric"]
      doAssert namesBeforeKindViaTemplate() == @["myField", "myGeneric"]
    check:
      namesBeforeKind() == @["myField", "myGeneric"]
      namesBeforeKindViaTemplate() == @["myField", "myGeneric"]

    template skip() = continue
    check:
      not compiles(block:
        for _, _ in fieldTypePairs(MyType[string]):
          continue)
      not compiles(block:
        for _, _ in fieldTypePairs(MyType[string]):
          skip())
      not compiles(block:
        for _, _ in fieldTypePairs(int):
          discard)
