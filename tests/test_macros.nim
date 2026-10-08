# Copyright (c) 2020-2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2,
  ../stew/shims/macros

template unknown() {.pragma.}
template zero() {.pragma.}
template one(one: string) {.pragma.}
template two(one: string, two: string) {.pragma.}

type
  MyType[T] = object
    myField {.zero, one("foo"), two("foo", "bar")}: string
    myGeneric {.zero.}: T
    case kind {.zero.}: bool
      of true:
        first {.zero.}: string
      else:
        second {.zero.}: string

  FieldKind = enum
    KindA
    KindB

  BaseType = object of RootObj
    baseField: int
    case baseCaseField: FieldKind
    of KindA:
      baseA: int
    of KindB:
      discard

  DerivedType = ref object of BaseType
    derivedField: int

  DerivedFromRefType = ref object of DerivedType
    anotherDerivedField: string

  GenericBaseType[T] = object of RootObj
    genericBaseField: T

  GenericDerivedType[T] = object of GenericBaseType[seq[T]]
    genericDerivedField: T

  DerivedFromGenericType = object of GenericDerivedType[int]
    derivedField: int

  IntBaseType = GenericBaseType[int]
  AliasBaseType = IntBaseType

  DerivedFromAliasType = object of AliasBaseType
    aliasDerivedField: int

  TypeofAliasType = typeof(DerivedFromAliasType())

  PublicType* {.zero.} = ref object of GenericBaseType[int]
    publicField* {.zero.}: int

  PtrType = ptr object of GenericBaseType[int]
    ptrField {.zero.}: int

  QuotedType = object
    `quoted field` {.one("quoted").}: int
    `type`: int

  EmptyObject = object
  EmptyRefObject = ref object

func fieldsList(typeImpl: NimNode): NimNode =
  let fields = newTree(nnkBracket)
  for f in recordFields(typeImpl):
    var field = ""
    if f.caseField != nil:
      field.add $f.caseField[0].skipPragma
      if f.caseBranch.kind == nnkElse:
        field.add " else"
      for i in 0 ..< f.caseBranch.len - 1:
        field.add(if i == 0: " of " else: ", ")
        field.add f.caseBranch[i].repr
      field.add ": "
    if f.isDiscriminator:
      field.add "case "
    field.add f.name.repr
    if f.isPublic:
      field.add "*"
    field.add ": " & f.typ.repr
    if f.pragmas != nil:
      field.add f.pragmas.repr
    fields.add newLit(field)
  if fields.len > 0:
    fields
  else:
    quote do: array[0, string](`fields`)

macro typeFieldsLists(T: type): untyped =
  fieldsList(T.getTypeInst[1])

macro typeImplFieldsLists(T: type): untyped =
  fieldsList(T.getTypeInst[1].getTypeImpl)

template getFieldsLists(T: type): untyped =
  block:
    const res = typeFieldsLists(T)
    doAssert typeImplFieldsLists(T) == res
    res

macro getUntypedFieldsLists(typeSection: untyped): untyped =
  let typeDef = typeSection[0][0]
  let genSymTypeDef = typeDef.copyNimTree
  genSymTypeDef[0] = genSym(nskType, $typeDef[0])
  let res = fieldsList(typeDef)
  doAssert fieldsList(typeDef[2]) == res
  doAssert fieldsList(genSymTypeDef) == res
  res

static:
  doAssert getFieldsLists(MyType[string]) == [
    "myField: string {.zero, one(\"foo\"), two(\"foo\", \"bar\").}",
    "myGeneric: string {.zero.}",
    "case kind: bool {.zero.}",
    "kind of true: first: string {.zero.}",
    "kind else: second: string {.zero.}"
  ]

  doAssert getFieldsLists(DerivedFromRefType) == [
    "baseField: int",
    "case baseCaseField: FieldKind",
    "baseCaseField of KindA: baseA: int",
    "derivedField: int",
    "anotherDerivedField: string"
  ]

  doAssert getFieldsLists(GenericDerivedType[int]) == [
    "genericBaseField: seq[int]",
    "genericDerivedField: int"
  ]

  doAssert getFieldsLists(DerivedFromGenericType) == [
    "genericBaseField: seq[int]",
    "genericDerivedField: int",
    "derivedField: int"
  ]

  doAssert getFieldsLists(DerivedFromAliasType) == [
    "genericBaseField: int",
    "aliasDerivedField: int"
  ]

  doAssert getFieldsLists(TypeofAliasType) == [
    "genericBaseField: int",
    "aliasDerivedField: int"
  ]

  doAssert getFieldsLists(PublicType) == [
    "genericBaseField: int",
    "publicField*: int {.zero.}"
  ]

  doAssert getFieldsLists(PtrType) == [
    "genericBaseField: int",
    "ptrField: int {.zero.}"
  ]

  doAssert getFieldsLists(QuotedType) == [
    "`quoted field`: int {.one(\"quoted\").}",
    "`type`: int"
  ]

  doAssert getFieldsLists(EmptyObject).len == 0
  doAssert getFieldsLists(EmptyRefObject).len == 0

  const untypedFieldsLists = getUntypedFieldsLists:
    type U = object
      untypedField {.zero.}: int
  doAssert untypedFieldsLists == [
    "untypedField: int {.zero.}"
  ]

let myType = MyType[string](
  myField: "test", myGeneric: "test", kind: true, first: "test")

suite "Macros":
  test "hasCustomPragmaFixed":
    check:
      not myType.type.hasCustomPragmaFixed("myField", unknown)
      myType.type.hasCustomPragmaFixed("myField", zero)
      myType.type.hasCustomPragmaFixed("myField", one)
      myType.type.hasCustomPragmaFixed("myField", two)

      myType.type.hasCustomPragmaFixed("myGeneric", zero)
      myType.type.hasCustomPragmaFixed("kind", zero)
      myType.type.hasCustomPragmaFixed("first", zero)
      myType.type.hasCustomPragmaFixed("second", zero)

      QuotedType.hasCustomPragmaFixed("quotedField", one)
      not QuotedType.hasCustomPragmaFixed("type", one)

  test "getCustomPragmaFixed":
    check:
      myType.type.getCustomPragmaFixed("myField", unknown).isNil
      myType.type.getCustomPragmaFixed("myField", zero).isNil
      myType.type.getCustomPragmaFixed("myField", one) is string
      myType.type.getCustomPragmaFixed("myField", two) is tuple[one: string, two: string]

      myType.type.getCustomPragmaFixed("myGeneric", zero).isNil
      myType.type.getCustomPragmaFixed("kind", zero).isNil
      myType.type.getCustomPragmaFixed("first", zero).isNil
      myType.type.getCustomPragmaFixed("second", zero).isNil

      QuotedType.getCustomPragmaFixed("quotedField", one) == "quoted"
