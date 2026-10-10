# Copyright (c) 2020-2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2,
  ../stew/shims/macros

from ./test_macros_helpers import helperZero, HelperBaseType

template unknown() {.pragma.}
template zero() {.pragma.}
template one(one: string) {.pragma.}
template two(one: string, two: string) {.pragma.}
{.pragma: zeroAlias, zero.}

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

  ErrorType = object of CatchableError
    errorField {.zero.}: int

  DerivedFromHelperType = object of HelperBaseType
    helperDerivedField: int

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
    pubBaseField* {.zero.}: T

  TypeofGenericType = typeof(PublicBaseType[int]())

  DerivedFromTypeofGenericType = object of TypeofGenericType

  DefaultGenericType = typeof(default(PublicBaseType[string]))

  DerivedFromDefaultGenericType = object of DefaultGenericType

  WhenBaseType[T] = object of RootObj
    when T is int:
      whenField {.zero.}: int
    else:
      whenField {.one("else").}: string
  # `WhenRefType[T] = ref object`: https://github.com/nim-lang/Nim/issues/26374

  DerivedFromWhenType = object of WhenBaseType[string]

  TypeofWhenType = typeof(WhenBaseType[int]())

  DerivedFromTypeofWhenType = object of TypeofWhenType

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

  GenericRefType[T] = ref object
    genericRefField {.zero.}: T

  PublicType* {.zero.} = ref object of GenericBaseType[int]
    publicField* {.zero.}: int
    case publicKind* {.zero.}: bool
    of true:
      publicBranch*: int
    of false:
      discard

  PtrType = ptr object of GenericBaseType[int]
    ptrField {.zero.}: int

  RefPtrType = ref PtrType

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

  PragmaAliasType = object
    aliasField {.zeroAlias.}: int

  TupleType = tuple[tupleField: int]
  UnnamedTupleType = (int, string)
  RefTupleType = ref tuple[refTupleField: int]
  PtrUnnamedTupleType = ptr (int, string)
  PtrRefTupleType = ptr ref TupleType
  RefPtrUnnamedTupleType = ref ptr UnnamedTupleType

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

template gensymBaseType(typeName: untyped) =
  type
    GensymBaseType = object of RootObj
      gensymBaseField {.zero.}: int
    typeName = object of GensymBaseType

gensymBaseType(DerivedFromGensymType)

macro macroType(): untyped =
  let
    pragmas = nnkPragma.newTree(ident "zero")
    field = nnkIdentDefs.newTree(
      nnkPragmaExpr.newTree(ident "macroField", pragmas),
      ident "int", newEmptyNode())
    objectType = nnkObjectTy.newTree(
      newEmptyNode(), newEmptyNode(), nnkRecList.newTree(field))
  nnkTypeSection.newTree(
    nnkTypeDef.newTree(ident "MacroType", newEmptyNode(), objectType))

macroType()

func fieldsList(typeImpl: NimNode): NimNode =
  let fields = newTree(nnkBracket)
  for f in recordFields(typeImpl):
    var field = ""
    if f.caseField != nil:
      field.add $f.caseFieldName
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

macro typeParamFieldsLists(T: type): untyped =
  fieldsList(T)

template getFieldsLists(T: type): untyped =
  block:
    const res = typeInstFieldsLists(T)
    doAssert typeImplFieldsLists(T) == res
    when T isnot tuple:  # getType has no tuple field names
      doAssert typeFieldsLists(T) == res
    doAssert typeDefFieldsLists(T) == res
    doAssert typeParamFieldsLists(T) == res
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

macro quotedRefFieldsLists(): untyped =
  let typeSection = quote do:
    type U = ref object of RefBaseType
      quotedField {.zero.}: int
  untypedFieldsLists(typeSection[0])

func zeroFields(T: type): seq[string] =
  var fields: seq[string]
  for name, _ in default(T).fieldPairs:
    when T.hasCustomPragmaFixed(name, zero):
      fields.add name
  fields

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

  doAssert getFieldsLists(ErrorType)[^1] == "errorField: int {.zero.}"

  doAssert getFieldsLists(test_macros_helpers.MyType) == [
    "helperField*: int {.helperZero.}"
  ]

  doAssert getFieldsLists(DerivedFromHelperType) == [
    "helperBaseField*: int {.helperZero.}",
    "helperPrivateField: int {.helperZero.}",
    "helperDerivedField: int"
  ]

  doAssert getFieldsLists(GenericDerivedType[int]) == [
    "genericBaseField: seq[int] {.zero.}",
    "genericDerivedField: int"
  ]

  doAssert GenericDerivedType[int].zeroFields == @["genericBaseField"]

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

  doAssert getFieldsLists(RefIntBaseType) == [
    "genericBaseField: int {.zero.}"
  ]

  doAssert getFieldsLists(DerivedFromAliasType) == [
    "genericBaseField: int {.zero.}",
    "aliasDerivedField: int {.zero.}"
  ]

  doAssert getFieldsLists(TypeofAliasType) == [
    "genericBaseField: int {.zero.}",
    "aliasDerivedField: int {.zero.}"
  ]

  doAssert getFieldsLists(PublicBaseType[int]) == [
    "pubBaseField*: int {.zero.}"
  ]

  doAssert getFieldsLists(DerivedFromTypeofGenericType) == [
    "pubBaseField*: int {.zero.}"
  ]

  doAssert getFieldsLists(DerivedFromDefaultGenericType) == [
    "pubBaseField*: string {.zero.}"
  ]

  doAssert getFieldsLists(WhenBaseType[int]) == [
    "whenField: int {.zero.}"
  ]

  doAssert getFieldsLists(DerivedFromWhenType) == [
    "whenField: string {.one(\"else\").}"
  ]

  doAssert getFieldsLists(DerivedFromTypeofWhenType) == [
    "whenField: int {.zero.}"
  ]

  doAssert getFieldsLists(StaticType[2]) == [
    "staticField: array[0 .. 1, byte] {.zero.}",
    "staticWhenField: int {.one(\"big\").}"
  ]

  doAssert getFieldsLists(WhenInCaseType[string]) == [
    "case whenInCaseKind: bool",
    "whenInCaseKind of true: whenInCaseField: string {.one(\"else\").}"
  ]

  doAssert getFieldsLists(PublicType) == [
    "genericBaseField: int {.zero.}",
    "publicField*: int {.zero.}",
    "case publicKind*: bool {.zero.}",
    "publicKind of true: publicBranch*: int"
  ]

  doAssert getFieldsLists(PtrType) == [
    "genericBaseField: int {.zero.}",
    "ptrField: int {.zero.}"
  ]

  doAssert getFieldsLists(RefPtrType) == getFieldsLists(PtrType)

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

  doAssert getFieldsLists(PragmaAliasType) == [
    "aliasField: int {.zero.}"
  ]

  doAssert getFieldsLists(EmptyObject).len == 0
  doAssert getFieldsLists(EmptyRefObject).len == 0

  doAssert getFieldsLists(TupleType) == [
    "tupleField: int"
  ]

  doAssert getFieldsLists(UnnamedTupleType) == [
    "Field0: int",
    "Field1: string"
  ]

  doAssert getFieldsLists(RefTupleType) == [
    "refTupleField: int"
  ]

  doAssert getFieldsLists(PtrUnnamedTupleType) == [
    "Field0: int",
    "Field1: string"
  ]

  doAssert getFieldsLists(PtrRefTupleType) == getFieldsLists(TupleType)
  doAssert getFieldsLists(RefPtrUnnamedTupleType) ==
      getFieldsLists(UnnamedTupleType)

  doAssert getFieldsLists(WhenCaseType) == [
    "case second: bool",
    "second of true: sameField: string {.one(\"second\").}"
  ]

  doAssert getFieldsLists(DerivedFromGensymType) == [
    "gensymBaseField: int {.zero.}"
  ]

  doAssert getFieldsLists(MacroType) == [
    "macroField: int {.zero.}"
  ]

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

  const untypedGenericFieldsLists = getUntypedFieldsLists:
    type U[T] = object
      untypedField {.zero.}: T
  doAssert untypedGenericFieldsLists == [
    "untypedField: T {.zero.}"
  ]

  const untypedTupleFieldsLists = getUntypedFieldsLists:
    type U = tuple[untypedField: int]
  doAssert untypedTupleFieldsLists == [
    "untypedField: int"
  ]

  const untypedUnnamedTupleFieldsLists = getUntypedFieldsLists:
    type U = (int, string)
  doAssert untypedUnnamedTupleFieldsLists == [
    "Field0: int",
    "Field1: string"
  ]

  const untypedRefTupleFieldsLists = getUntypedFieldsLists:
    type U = ref tuple[untypedField: int]
  doAssert untypedRefTupleFieldsLists == [
    "untypedField: int"
  ]

  const untypedPtrUnnamedTupleFieldsLists = getUntypedFieldsLists:
    type U = ptr (int, string)
  doAssert untypedPtrUnnamedTupleFieldsLists == [
    "Field0: int",
    "Field1: string"
  ]

  const untypedPtrRefTupleFieldsLists = getUntypedFieldsLists:
    type U = ptr ref tuple[untypedField: int]
  doAssert untypedPtrRefTupleFieldsLists == untypedTupleFieldsLists

  const untypedRefPtrUnnamedTupleFieldsLists = getUntypedFieldsLists:
    type U = ref ptr (int, string)
  doAssert untypedRefPtrUnnamedTupleFieldsLists ==
      untypedUnnamedTupleFieldsLists

  doAssert quotedPtrFieldsLists() == [
    "ptrBaseField: int {.zero.}",
    "quotedField: int {.zero.}"
  ]

  doAssert quotedRefFieldsLists() == [
    "case refBaseKind: bool {.zero.}",
    "refBaseKind of true: refBaseField: int {.one(\"ref\").}",
    "quotedField: int {.zero.}"
  ]

let myType = MyType[string](
  myField: "test", myGeneric: "test", kind: true, first: "test")

suite "Macros":
  test "hasCustomPragmaFixed":
    type LocalType = object
      localField {.zero.}: int
    check:
      not myType.type.hasCustomPragmaFixed("myField", unknown)
      myType.type.hasCustomPragmaFixed("myField", zero)
      myType.type.hasCustomPragmaFixed("myField", one)
      myType.type.hasCustomPragmaFixed("myField", two)

      myType.type.hasCustomPragmaFixed("myGeneric", zero)
      myType.type.hasCustomPragmaFixed("kind", zero)
      myType.type.hasCustomPragmaFixed("first", zero)
      myType.type.hasCustomPragmaFixed("second", zero)
      not myType.type.hasCustomPragmaFixed("myField", helperZero)

      DerivedFromRefBaseType.hasCustomPragmaFixed("refBaseKind", zero)
      ErrorType.hasCustomPragmaFixed("errorField", zero)
      not ErrorType.hasCustomPragmaFixed("msg", zero)
      test_macros_helpers.MyType.hasCustomPragmaFixed("helperField", helperZero)
      not test_macros_helpers.MyType.hasCustomPragmaFixed("helperField", zero)
      DerivedFromHelperType.hasCustomPragmaFixed("helperBaseField", helperZero)
      MultiDerivedType[int, string].hasCustomPragmaFixed("multiBaseField", two)
      DerivedFromTypeofGenericType.hasCustomPragmaFixed("pubBaseField", zero)
      DerivedFromDefaultGenericType.hasCustomPragmaFixed("pubBaseField", zero)
      not WhenBaseType[string].hasCustomPragmaFixed("whenField", zero)
      WhenBaseType[string].hasCustomPragmaFixed("whenField", one)
      not DerivedFromWhenType.hasCustomPragmaFixed("whenField", zero)
      DerivedFromWhenType.hasCustomPragmaFixed("whenField", one)
      DerivedFromTypeofWhenType.hasCustomPragmaFixed("whenField", zero)
      StaticType[2].hasCustomPragmaFixed("staticWhenField", one)
      WhenInCaseType[int].hasCustomPragmaFixed("whenInCaseField", zero)
      not WhenInCaseType[string].hasCustomPragmaFixed("whenInCaseField", zero)
      GenericRefType[int].hasCustomPragmaFixed("genericRefField", zero)
      PublicType.hasCustomPragmaFixed("publicField", zero)
      PublicType.hasCustomPragmaFixed("publicKind", zero)
      PtrType.hasCustomPragmaFixed("ptrField", zero)
      QuotedType.hasCustomPragmaFixed("quotedField", one)
      not QuotedType.hasCustomPragmaFixed("type", one)
      SharedIdentDefsType.hasCustomPragmaFixed("sharedB", zero)
      not SharedIdentDefsType.hasCustomPragmaFixed("sharedA", zero)
      NestedCaseType.hasCustomPragmaFixed("innerKind", zero)
      PragmaAliasType.hasCustomPragmaFixed("aliasField", zero)
      not TupleType.hasCustomPragmaFixed("tupleField", zero)
      not (int, string).hasCustomPragmaFixed("Field0", zero)
      DerivedFromGensymType.hasCustomPragmaFixed("gensymBaseField", zero)
      MacroType.hasCustomPragmaFixed("macroField", zero)
      LocalType.hasCustomPragmaFixed("localField", zero)
    when compiles(MyType[string].hasCustomPragmaFixed("unknownField", zero)):
      check false

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

      DerivedFromRefBaseType.getCustomPragmaFixed("refBaseField", one) == "ref"
      MultiDerivedType[int, string].getCustomPragmaFixed(
        "multiBaseField", two) == (one: "multi", two: "base")
      WhenBaseType[string].getCustomPragmaFixed("whenField", one) == "else"
      DerivedFromWhenType.getCustomPragmaFixed("whenField", one) == "else"
      StaticType[2].getCustomPragmaFixed("staticWhenField", one) == "big"
      WhenInCaseType[string].getCustomPragmaFixed(
        "whenInCaseField", one) == "else"
      QuotedType.getCustomPragmaFixed("quotedField", one) == "quoted"
      NestedCaseType.getCustomPragmaFixed("nestedField", one) == "nested"
      PragmaAliasType.getCustomPragmaFixed("aliasField", zero).isNil
      TupleType.getCustomPragmaFixed("tupleField", zero).isNil
      (int, string).getCustomPragmaFixed("Field0", zero).isNil
    when compiles(MyType[string].getCustomPragmaFixed("unknownField", zero)):
      check false
