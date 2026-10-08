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

  RefBaseObject = object of RootObj
    case refBaseKind {.zero.}: bool
    of true:
      refBaseField {.one("ref").}: int
    of false:
      discard

  RefBaseType = ref RefBaseObject

  DerivedFromRefBaseType = ref object of RefBaseType
    refBaseDerivedField {.zero.}: int

  GenericBaseType[T] = object of RootObj
    genericBaseField {.zero.}: T

  GenericDerivedType[T] = object of GenericBaseType[seq[T]]
    genericDerivedField: T

  DerivedFromGenericType = object of GenericDerivedType[int]
    derivedField: int

  MultiBaseType[A, B] = object of RootObj
    multiBaseField {.two("multi", "base").}: A
    multiOtherField: B

  MultiDerivedType[A, B] = object of MultiBaseType[B, A]
    multiDerivedField: A

  IntBaseType = GenericBaseType[int]
  AliasBaseType = IntBaseType
  RefIntBaseType = ref GenericBaseType[int]

  DerivedFromAliasType = object of AliasBaseType
    aliasDerivedField {.zero.}: int

  TypeofAliasType = typeof(DerivedFromAliasType())

  PublicBaseType[T] = object of RootObj
    publicBaseField*: T
  TypeofGenericType = typeof(PublicBaseType[int]())

  DerivedFromTypeofGenericType = object of TypeofGenericType

  WhenBaseType[T] = object of RootObj
    when T is int:
      whenField {.zero.}: int
    else:
      whenField {.one("else").}: string
  # `WhenRefType[T] = ref object`: https://github.com/nim-lang/Nim/issues/26374

  DerivedFromWhenType = object of WhenBaseType[string]

  StaticType[N: static int] = object
    staticField {.zero.}: array[N, byte]
    when N > 1:
      staticWhenField {.one("big").}: int

  WhenInCaseType[T] = object
    case whenInCaseKind: bool
    of true:
      when T is int:
        whenInCaseField {.zero.}: int
      else:
        whenInCaseField {.one("else").}: string
    of false:
      discard

  PublicType* {.zero.} = ref object of GenericBaseType[int]
    publicField* {.zero.}: int
    case publicKind* {.zero.}: bool
    of true:
      publicBranch*: int
    of false:
      discard

  PtrType = ptr object of GenericBaseType[int]
    ptrField {.zero.}: int

  PtrBaseType = ptr object of RootObj
    ptrBaseField {.zero.}: int

  QuotedType = object
    `quoted field` {.one("quoted").}: int
    `type`: int
    case `quoted kind`: bool
    of true:
      quotedBranch {.zero.}: int
    of false:
      discard

  SharedIdentDefsType = object
    sharedA, sharedB {.zero.}: int
    sharedC* {.one("c").}, sharedD: string

  NestedCaseType = object
    case outerKind: FieldKind
    of KindA, KindB:
      case innerKind {.zero.}: range[0 .. 3]
      of 1 .. 2:
        nestedField {.one("nested").}: int
      else:
        discard

  EmptyObject = object
  EmptyRefObject = ref object

template whenCaseType(typeName, sameField: untyped) =
  type typeName = object
    when false:
      case first: bool
      of true:
        sameField {.zero.}: int
      of false:
        discard
    else:
      case second: bool
      of true:
        sameField {.one("second").}: string
      of false:
        discard
# Using same field without `case`: https://github.com/nim-lang/Nim/issues/26373

whenCaseType(WhenCaseType, sameField)

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

macro typeInstFieldsLists(T: type): untyped =
  fieldsList(T.getTypeInst[1])

macro typeImplFieldsLists(T: type): untyped =
  fieldsList(T.getTypeInst[1].getTypeImpl)

macro typeFieldsLists(T: type): untyped =
  fieldsList(T.getType[1])

macro typeDefFieldsLists(T: type): untyped =
  let typ = T.getTypeInst[1]
  fieldsList(if typ.kind == nnkSym: typ.getImpl else: typ)

template getFieldsLists(T: type): untyped =
  block:
    const res = typeInstFieldsLists(T)
    doAssert typeImplFieldsLists(T) == res
    doAssert typeFieldsLists(T) == res
    doAssert typeDefFieldsLists(T) == res
    res

func untypedFieldsLists(typeDef: NimNode): NimNode =
  let genSymTypeDef = typeDef.copyNimTree
  genSymTypeDef[0] = genSym(nskType, $typeDef[0])
  let res = fieldsList(typeDef)
  doAssert fieldsList(typeDef[2]) == res
  doAssert fieldsList(genSymTypeDef) == res
  res

macro getUntypedFieldsLists(typeSection: untyped): untyped =
  untypedFieldsLists(typeSection[0][0])

macro quotedPtrFieldsLists(): untyped =
  let typeSection = quote do:
    type U = ptr object of PtrBaseType
      quotedField {.zero.}: int
  untypedFieldsLists(typeSection[0])

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

  doAssert getFieldsLists(RefBaseType) == [
    "case refBaseKind: bool {.zero.}",
    "refBaseKind of true: refBaseField: int {.one(\"ref\").}"
  ]

  doAssert getFieldsLists(ptr RefBaseObject) == getFieldsLists(RefBaseType)

  doAssert getFieldsLists(DerivedFromRefBaseType) == [
    "case refBaseKind: bool {.zero.}",
    "refBaseKind of true: refBaseField: int {.one(\"ref\").}",
    "refBaseDerivedField: int {.zero.}"
  ]

  doAssert getFieldsLists(GenericDerivedType[int]) == [
    "genericBaseField: seq[int] {.zero.}",
    "genericDerivedField: int"
  ]

  doAssert getFieldsLists(DerivedFromGenericType) == [
    "genericBaseField: seq[int] {.zero.}",
    "genericDerivedField: int",
    "derivedField: int"
  ]

  doAssert getFieldsLists(MultiDerivedType[int, string]) == [
    "multiBaseField: string {.two(\"multi\", \"base\").}",
    "multiOtherField: int",
    "multiDerivedField: int"
  ]

  doAssert getFieldsLists(DerivedFromAliasType) == [
    "genericBaseField: int {.zero.}",
    "aliasDerivedField: int {.zero.}"
  ]

  doAssert getFieldsLists(RefIntBaseType) == [
    "genericBaseField: int {.zero.}"
  ]

  doAssert getFieldsLists(TypeofAliasType) == [
    "genericBaseField: int {.zero.}",
    "aliasDerivedField: int {.zero.}"
  ]

  doAssert getFieldsLists(PublicBaseType[int]) == [
    "publicBaseField*: int"
  ]

  doAssert getFieldsLists(DerivedFromTypeofGenericType) == [
    "publicBaseField*: int"
  ]

  doAssert getFieldsLists(WhenBaseType[int]) == [
    "whenField: int {.zero.}"
  ]

  doAssert getFieldsLists(DerivedFromWhenType) == [
    "whenField: string {.one(\"else\").}"
  ]

  doAssert getFieldsLists(StaticType[2]) == [
    "staticField: array[0 .. 1, byte] {.zero.}",
    "staticWhenField: int {.one(\"big\").}"
  ]

  doAssert getFieldsLists(WhenInCaseType[string]) == [
    "case whenInCaseKind: bool",
    "whenInCaseKind of true: whenInCaseField: string {.one(\"else\").}"
  ]

  doAssert getFieldsLists(WhenCaseType) == [
    "case second: bool",
    "second of true: sameField: string {.one(\"second\").}"
  ]

  doAssert getFieldsLists(PublicType) == [
    "genericBaseField: int {.zero.}",
    "publicField*: int {.zero.}",
    "case publicKind*: bool {.zero.}",
    "publicKind* of true: publicBranch*: int"
  ]

  doAssert getFieldsLists(PtrType) == [
    "genericBaseField: int {.zero.}",
    "ptrField: int {.zero.}"
  ]

  doAssert getFieldsLists(QuotedType) == [
    "`quoted field`: int {.one(\"quoted\").}",
    "`type`: int",
    "case `quoted kind`: bool",
    "quotedkind of true: quotedBranch: int {.zero.}"
  ]

  doAssert getFieldsLists(SharedIdentDefsType) == [
    "sharedA: int",
    "sharedB: int {.zero.}",
    "sharedC*: string {.one(\"c\").}",
    "sharedD: string"
  ]

  doAssert getFieldsLists(NestedCaseType) == [
    "case outerKind: FieldKind",
    "outerKind of KindA, KindB: case innerKind: range[0 .. 3] {.zero.}",
    "innerKind of 1 .. 2: nestedField: int {.one(\"nested\").}"
  ]

  doAssert getFieldsLists(EmptyObject).len == 0
  doAssert getFieldsLists(EmptyRefObject).len == 0

  const untypedFieldsLists = getUntypedFieldsLists:
    type U = object
      untypedField {.zero.}: int
  doAssert untypedFieldsLists == [
    "untypedField: int {.zero.}"
  ]

  const untypedRefFieldsLists = getUntypedFieldsLists:
    type U = ref object
      untypedField {.zero.}: int
  doAssert untypedRefFieldsLists == [
    "untypedField: int {.zero.}"
  ]

  const untypedPtrFieldsLists = getUntypedFieldsLists:
    type U = ptr object
      untypedField {.zero.}: int
  doAssert untypedPtrFieldsLists == [
    "untypedField: int {.zero.}"
  ]

  doAssert quotedPtrFieldsLists() == [
    "ptrBaseField: int {.zero.}",
    "quotedField: int {.zero.}"
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
