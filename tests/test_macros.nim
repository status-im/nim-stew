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
template zeroOrOne() {.pragma.}
template zeroOrOne(one: string) {.pragma.}
{.pragma: zeroAlias, zero.}
{.pragma: reusedZeroAlias, zero.}

const elseOfKinds = {1, 2}

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
    kindA
    kindB

  HoleyKind = enum
    holeyA = 5
    holeyB = 20

  HoleyKindAlias = HoleyKind

  DescribedKind = enum
    describedA = "first"
    describedB

  ValuedKind = enum
    valuedA = -5
    valuedB = (10, "ten")
    valuedC = "val" & "ued"
    valuedD {.deprecated.} = 'z'
    valuedE = (ord('z') + 5, "e")
    valuedF

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

  GenericBaseType[T] {.one("generic").} = object of RootObj
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
  AliasBaseType {.zero.} = IntBaseType
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

  PublicType* {.zero, one("public").} = ref object of GenericBaseType[int]
    publicField* {.zero.}: int
    case publicKind* {.zero.}: bool
    of true:
      publicBranch*: int
    of false:
      discard

  PublicAliasType = PublicType

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
    of kindA, kindB:
      case innerKind {.zero.}: range[0 .. 3]
      of 1 .. 2:
        nestedField {.one("nested").}: int
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

  PragmaAliasType = object
    aliasField {.zeroAlias.}: int

  ReusedPragmaAliasType = object
    firstAliasField {.reusedZeroAlias.}: int
    secondAliasField {.reusedZeroAlias.}: int
    callField {.zero().}: int
    bareField {.zero.}: int

  TupleType = tuple[tupleField: int]
  UnnamedTupleType = (int, string)
  RefTupleType = ref tuple[refTupleField: int]
  PtrUnnamedTupleType = ptr (int, string)
  PtrRefTupleType = ptr ref TupleType
  RefPtrUnnamedTupleType = ref ptr UnnamedTupleType
  GenericTupleType[T] = tuple[genericTupleField: T]
  GenericTupleAliasType = GenericTupleType[int]
  ErrorAliasType = ErrorType
  AliasTupleType = (ErrorAliasType, UnnamedTupleType)

  EmptyObject = object
  EmptyRefObject = ref object

  CallGenericType[T] {.one("call").} = object
    callField {.zero.}: T

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

macro whenSharedCaseType(): untyped =
  let typeSection = quote do:
    type WhenSharedCaseType {.inject.} = object
      when sizeof(int) > 0:
        case whenSharedKind: bool
        of true:
          whenSharedField {.zero.}: int
        of false:
          discard
      else:
        discard
  let recWhen = typeSection[0][2][2][0]
  recWhen[1][0] = recWhen[0][1].copyNimTree
  typeSection

whenSharedCaseType()

template templateCallType(T: type): untyped = CallGenericType[T]

template templateCallKind(): untyped = HoleyKind

macro macroCallType(T: type): untyped =
  quote do: CallGenericType[`T`]

type
  TemplateCallAliasType = templateCallType(int)
  DotTemplateCallAliasType = string.templateCallType
  MacroCallAliasType = macroCallType(bool)
  TemplateCallAliasKind = templateCallKind()
  TypeofAliasKind = typeof(holeyA)

func fieldDescriptions(fields: seq[FieldDescription]): seq[string] =
  var res: seq[string]
  for f in fields:
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
    res.add field
  res

func fieldsList(typeImpl: NimNode): NimNode =
  let fields = newTree(nnkBracket)
  for field in fieldDescriptions(recordFields(typeImpl)):
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

macro valueTypeFieldsLists(value: typed): untyped =
  fieldsList(value.getType)

macro typeInstIsTuple(T: type): untyped =
  newLit(T.getTypeInst[1].isTuple)

macro typeImplIsTuple(T: type): untyped =
  newLit(T.getTypeInst[1].getTypeImpl.isTuple)

macro typeIsTuple(T: type): untyped =
  newLit(T.getType[1].isTuple)

macro typeDefIsTuple(T: type): untyped =
  let typ = T.getTypeInst[1]
  newLit(isTuple(if typ.kind == nnkSym: typ.getImpl else: typ))

macro typeParamIsTuple(T: type): untyped =
  newLit(T.isTuple)

macro valueTypeIsTuple(value: typed): untyped =
  newLit(value.getType.isTuple)

template getIsTuple(T: type): untyped =
  block:
    const res = typeInstIsTuple(T)
    doAssert typeImplIsTuple(T) == res
    doAssert typeIsTuple(T) == res
    doAssert typeDefIsTuple(T) == res
    doAssert typeParamIsTuple(T) == res
    doAssert valueTypeIsTuple(default(T)) == res
    res

macro typeHumaneName(T: type): untyped =
  newLit(humaneTypeName(T))

func enumFieldsList(typ: NimNode): NimNode =
  var res: seq[string]
  for field in enumFields(typ):
    var description = $field.name
    if field.value != nil:
      description.add " = " & field.value.repr
    description.add ": " & $(field.ordinal, field.strValue)
    res.add description
  newLit res

macro typeInstEnumFieldsList(T: type): untyped =
  enumFieldsList(T.getTypeInst[1])

macro typeImplEnumFieldsList(T: type): untyped =
  enumFieldsList(T.getTypeInst[1].getTypeImpl)

macro typeEnumFieldsList(T: type): untyped =
  enumFieldsList(T.getType[1])

macro typeDefEnumFieldsList(T: type): untyped =
  let typ = T.getTypeInst[1]
  enumFieldsList(if typ.kind == nnkSym: typ.getImpl else: typ)

macro typeParamEnumFieldsList(T: type): untyped =
  enumFieldsList(T)

macro valueTypeEnumFieldsList(value: typed): untyped =
  enumFieldsList(value.getType)

template getEnumFieldsList(T: type): untyped =
  block:
    const res = typeInstEnumFieldsList(T)
    doAssert typeImplEnumFieldsList(T) == res
    doAssert typeEnumFieldsList(T) == res
    doAssert typeDefEnumFieldsList(T) == res
    doAssert typeParamEnumFieldsList(T) == res
    doAssert valueTypeEnumFieldsList(default(T)) == res
    res

func tupleTypesList(typ: NimNode): NimNode =
  var res: seq[string]
  for elementType in tupleTypes(typ):
    res.add elementType.repr
  newLit res

macro typeInstTupleTypesList(T: type): untyped =
  tupleTypesList(T.getTypeInst[1])

macro typeImplTupleTypesList(T: type): untyped =
  tupleTypesList(T.getTypeInst[1].getTypeImpl)

macro typeTupleTypesList(T: type): untyped =
  tupleTypesList(T.getType[1])

macro typeParamTupleTypesList(T: type): untyped =
  tupleTypesList(T)

macro valueTypeTupleTypesList(value: typed): untyped =
  tupleTypesList(value.getType)

template getTupleTypesList(T: type): untyped =
  block:
    const res = typeInstTupleTypesList(T)
    doAssert typeImplTupleTypesList(T) == res
    doAssert typeTupleTypesList(T) == res
    doAssert typeParamTupleTypesList(T) == res
    doAssert valueTypeTupleTypesList(default(T)) == res
    res

func typeDescFieldsLists(T: type): seq[string] {.compileTime.} =
  fieldDescriptions(recordFields(T))

template getFieldsLists(T: type): untyped =
  block:
    const res = typeInstFieldsLists(T)
    doAssert typeImplFieldsLists(T) == res
    doAssert typeFieldsLists(T) == res
    doAssert typeDefFieldsLists(T) == res
    doAssert typeParamFieldsLists(T) == res
    doAssert valueTypeFieldsLists(default(T)) == res
    doAssert typeDescFieldsLists(T) == @res
    res

func caseBranchValuesList(typ: NimNode): NimNode =
  let values = newTree(nnkBracket)
  for field in recordFields(typ):
    if field.caseBranchValues != nil:
      let
        name = newLit(field.name.repr)
        branchValues = field.caseBranchValues
      values.add quote do: `name` & ": " & $`branchValues`
  values

macro typeInstCaseBranchValuesList(T: type): untyped =
  caseBranchValuesList(T.getTypeInst[1])

macro typeImplCaseBranchValuesList(T: type): untyped =
  caseBranchValuesList(T.getTypeInst[1].getTypeImpl)

macro typeCaseBranchValuesList(T: type): untyped =
  caseBranchValuesList(T.getType[1])

macro typeDefCaseBranchValuesList(T: type): untyped =
  let typ = T.getTypeInst[1]
  caseBranchValuesList(if typ.kind == nnkSym: typ.getImpl else: typ)

macro typeParamCaseBranchValuesList(T: type): untyped =
  caseBranchValuesList(T)

macro valueTypeCaseBranchValuesList(value: typed): untyped =
  caseBranchValuesList(value.getType)

template getCaseBranchValuesList(T: type): untyped =
  block:
    const res = typeInstCaseBranchValuesList(T)
    doAssert typeImplCaseBranchValuesList(T) == res
    doAssert typeCaseBranchValuesList(T) == res
    doAssert typeDefCaseBranchValuesList(T) == res
    doAssert typeParamCaseBranchValuesList(T) == res
    doAssert valueTypeCaseBranchValuesList(default(T)) == res
    res

func containedValuesList(typ: NimNode): NimNode =
  let values = newTree(nnkBracket)
  for field in recordFields(typ):
    if field.caseBranchValues != nil:
      let
        name = newLit(field.name.repr)
        branchValues = field.caseBranchValues
        contained = newTree(nnkBracket)
      for ordinal in 0'i64 .. 3:
        contained.add newLit(branchValues.containsOrdinal(ordinal))
      values.add quote do:
        block:
          type Discriminator = typeof(items(`branchValues`))
          var res: set[Discriminator]
          for value in Discriminator.low .. Discriminator.high:
            if `contained`[ord(value)]:
              res.incl value
          `name` & ": " & $res
  values

macro typeInstContainedValuesList(T: type): untyped =
  containedValuesList(T.getTypeInst[1])

macro typeImplContainedValuesList(T: type): untyped =
  containedValuesList(T.getTypeInst[1].getTypeImpl)

macro typeContainedValuesList(T: type): untyped =
  containedValuesList(T.getType[1])

macro typeDefContainedValuesList(T: type): untyped =
  let typ = T.getTypeInst[1]
  containedValuesList(if typ.kind == nnkSym: typ.getImpl else: typ)

macro typeParamContainedValuesList(T: type): untyped =
  containedValuesList(T)

macro valueTypeContainedValuesList(value: typed): untyped =
  containedValuesList(value.getType)

template getContainedValuesList(T: type): untyped =
  block:
    const res = typeInstContainedValuesList(T)
    doAssert typeImplContainedValuesList(T) == res
    doAssert typeContainedValuesList(T) == res
    doAssert typeDefContainedValuesList(T) == res
    doAssert typeParamContainedValuesList(T) == res
    doAssert valueTypeContainedValuesList(default(T)) == res
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

func genericIsCaseObject(T: type): bool =
  isCaseObject(T)

func genericHasField(T: type, name: static string): bool =
  hasField(T, name)

func compileTimeIsCaseObject(T: type): bool {.compileTime.} =
  isCaseObject(T)

func compileTimeHasField(T: type, name: static string): bool {.compileTime.} =
  hasField(T, name)

macro macroIsCaseObject(): untyped =
  newLit(isCaseObject(MyType[string]))

macro macroHasField(): untyped =
  newLit(hasField(MyType[string], "myField"))

macro overloadedPragma(body: untyped): untyped = body
macro overloadedPragma(arg, body: untyped): untyped = body

macro hasOverloadedPragma(procSection: untyped): untyped =
  newLit(procSection[0].pragma.findPragma(ident "overloadedPragma") != nil)

template templateHasOverloadedPragma(): untyped =
  hasOverloadedPragma:
    proc templateProc() {.overloadedPragma.}

template bindHasOverloadedPragma(): untyped =
  bind overloadedPragma
  hasOverloadedPragma:
    proc bindProc() {.overloadedPragma.}

iterator overloadedPragmaValueNodes(procSection: NimNode): NimNode =
  for procDef in procSection:
    yield procDef.pragma.readPragma("overloadedPragma")

macro overloadedPragmaValues(procSection: untyped): untyped =
  var values: seq[string]
  for value in overloadedPragmaValueNodes(procSection):
    values.add(
      if value == nil: ""
      elif value.kind in nnkStrLit .. nnkTripleStrLit: value.strVal
      else: $value)
  newLit values

template templateOverloadedPragmaValues(): untyped =
  overloadedPragmaValues:
    proc bareProc() {.overloadedPragma.}
    proc colonProc() {.overloadedPragma: "colon".}
    proc callProc() {.overloadedPragma("call").}
    proc strLitProc() {.overloadedPragma"strLit".}
    proc otherProc() {.zero.}

template bindOverloadedPragmaValues(): untyped =
  bind overloadedPragma
  overloadedPragmaValues:
    proc bareProc() {.overloadedPragma.}
    proc colonProc() {.overloadedPragma: "colon".}
    proc callProc() {.overloadedPragma("call").}
    proc strLitProc() {.overloadedPragma"strLit".}
    proc otherProc() {.zero.}

macro readBoundOverloadedPragma(): untyped =
  let
    pragma = bindSym "overloadedPragma"
    field = nnkIdentDefs.newTree(
      nnkPragmaExpr.newTree(ident "boundField", nnkPragma.newTree(pragma)),
      ident "int", newEmptyNode())
    objectType = nnkObjectTy.newTree(
      newEmptyNode(), newEmptyNode(), nnkRecList.newTree(field))
  newLit(recordFields(objectType)[0].readPragma("overloadedPragma") == pragma)

macro readBoundOverloadedPragmaPresence(): untyped =
  let
    field = nnkIdentDefs.newTree(
      nnkPragmaExpr.newTree(
        ident "boundField",
        nnkPragma.newTree(bindSym "overloadedPragma")),
      ident "int", newEmptyNode())
    objectType = nnkObjectTy.newTree(
      newEmptyNode(), newEmptyNode(), nnkRecList.newTree(field))
  newLit recordFields(objectType)[0].hasPragma("overloadedPragma")

macro zeroPragmaPresence(T: type): untyped =
  var present: seq[bool]
  for field in recordFields(T):
    present.add field.hasPragma("zero")
  newLit present

macro getOnePresence(routine: untyped): untyped =
  var present: seq[bool]
  for param in routineParams(routine[0]):
    present.add param.hasPragma("one")
  newLit present

func pragmaLists(routines: NimNode): NimNode =
  var names, present, values: seq[string]
  for routine in routines:
    if routine.kind notin RoutineNodes:
      continue
    let pragmas = routine.pragma
    for p in pragmas:
      names.add $p.pragmaName
    for name in ["zeroOrOne", "zero", "unknown", "raises", "gcsafe"]:
      if pragmas.hasPragma(name):
        present.add name
    let value = pragmas.readPragmaValue("zeroOrOne")
    values.add(if value == nil: "" else: value.strVal)
  newLit (names: names, present: present, values: values)

macro getPragmaLists(routines: untyped): untyped =
  pragmaLists(routines)

macro getTypedPragmaLists(routines: typed): untyped =
  pragmaLists(routines)

template zeroOrOneProcs(getLists: untyped): untyped =
  getLists:
    proc bareProc() {.zeroOrOne.} = discard
    proc emptyProc() {.zeroOrOne().} = discard
    proc colonProc() {.zeroOrOne: "colon".} = discard
    proc callProc() {.zeroOrOne("call").} = discard
    proc strLitProc() {.zeroOrOne"strLit".} = discard
    proc otherProc() {.zero, raises: [], gcsafe.} = discard

template bindZeroOrOneProcs(getLists: untyped): untyped =
  bind zeroOrOne, zero
  getLists:
    proc bareProc() {.zeroOrOne.} = discard
    proc emptyProc() {.zeroOrOne().} = discard
    proc colonProc() {.zeroOrOne: "colon".} = discard
    proc callProc() {.zeroOrOne("call").} = discard
    proc strLitProc() {.zeroOrOne"strLit".} = discard
    proc otherProc() {.zero, raises: [], gcsafe.} = discard

macro getZeroOrOneValues(routine: untyped): untyped =
  var values: seq[string]
  for param in routineParams(routine[0]):
    let value = param.readPragmaValue("zeroOrOne")
    values.add(if value == nil: "" else: value.strVal)
  newLit values

func paramsList(n: NimNode): NimNode =
  var res: seq[string]
  for param in routineParams(n):
    var description = param.name.identName
    if param.typ.kind != nnkEmpty:
      description.add ": " & param.typ.repr
    if param.defaultValue.kind != nnkEmpty:
      description.add " = " & param.defaultValue.repr
    if param.pragmas != nil:
      description.add param.pragmas.repr
    res.add description
  newLit res

macro getParamsList(routine: untyped): untyped =
  let
    routine = if routine.kind == nnkStmtList: routine[0] else: routine
    res = paramsList(routine)
  doAssert paramsList(routine.params) == res
  res

macro getOneValues(routine: untyped): untyped =
  var values: seq[string]
  for param in routineParams(routine[0]):
    let value = param.readPragma("one")
    values.add(if value == nil: "" else: value.strVal)
  newLit values

template templateParamsList(): untyped =
  getParamsList:
    proc paramsTemplate(a, b {.zero.}: int, c: string = "c", d = 1): string

template nestedParamsList(): untyped =
  template nestedTemplateParamsList(): untyped =
    getParamsList:
      proc paramsNested(a, b {.zero.}: int, c: string = "c", d = 1): string
  nestedTemplateParamsList()

macro getIdentNames(section: untyped): untyped =
  var names: seq[string]
  for n in section:
    case n.kind
    of nnkProcDef:
      names.add n[0].identName
      for param in routineParams(n):
        names.add param.name.identName
    of nnkTypeSection:
      names.add n[0][0].identName
      for field in n[0][2][2]:
        names.add field[0].identName
    of nnkLetSection:
      names.add n[0][0].identName
    else:
      doAssert false
  newLit names

template templateIdentNames(names: untyped) =
  const names = getIdentNames:
    proc identProc*(`type`, `quoted name` {.zero.}: int)
    type IdentType* {.zero.} = object
      identField* {.zero.}: int
    let identLet {.used.} = 0

template nestedIdentNames(names: untyped) =
  template nestedTemplateIdentNames(innerNames: untyped) =
    const innerNames = getIdentNames:
      proc identProc*(`type`, `quoted name` {.zero.}: int)
      type IdentType* {.zero.} = object
        identField* {.zero.}: int
      let identLet {.used.} = 0
  nestedTemplateIdentNames(names)

macro getTypedIdentNames(routine: typed): untyped =
  let routine = if routine.kind == nnkStmtList: routine[0] else: routine
  var names: seq[string]
  for param in routineParams(routine):
    names.add param.name.identName
  newLit names

template templateTypedIdentNames(): untyped =
  getTypedIdentNames:
    proc typedIdentProc(`type`, `quoted name` {.zero.}: int) = discard

func bracketExprsList(routine: NimNode): NimNode =
  let routine = if routine.kind == nnkStmtList: routine[0] else: routine
  var res: seq[(bool, string)]
  for param in routineParams(routine):
    let typ = param.typ.bracketExpr
    res.add (typ.kind == nnkBracketExpr, typ.repr)
  newLit res

macro getBracketExprs(routine: untyped): untyped =
  bracketExprsList(routine)

macro getTypedBracketExprs(routine: typed): untyped =
  bracketExprsList(routine)

template bracketExprProcs(getList: untyped): untyped =
  getList:
    proc bracketProc(
        a: seq[int], b: GenericBaseType[seq[byte]], c: array[2, int], d: int,
        e: `[]`(seq, string)) = discard

template bindBracketExprProcs(getList: untyped): untyped =
  bind `[]`
  getList:
    proc bracketProc(
        a: seq[int], b: GenericBaseType[seq[byte]], c: array[2, int], d: int,
        e: `[]`(seq, string)) = discard

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
    "baseCaseField of kindA: baseA: int",
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

  doAssert getFieldsLists(typeof(DerivedFromAliasType())) == [
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
    "outerKind of kindA, kindB: case innerKind: range[0 .. 3] {.zero.}",
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

  doAssert getFieldsLists(PtrRefTupleType) == [
    "tupleField: int"
  ]

  doAssert getFieldsLists(RefPtrUnnamedTupleType) == [
    "Field0: int",
    "Field1: string"
  ]

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

  doAssert getFieldsLists(WhenSharedCaseType) == [
    "case whenSharedKind: bool",
    "whenSharedKind of true: whenSharedField: int {.zero.}"
  ]

  doAssert getFieldsLists(CallGenericType[int]) == [
    "callField: int {.zero.}"
  ]

  doAssert getFieldsLists(TemplateCallAliasType) == [
    "callField: int {.zero.}"
  ]

  doAssert getFieldsLists(templateCallType(int)) == [
    "callField: int {.zero.}"
  ]

  doAssert getFieldsLists(DotTemplateCallAliasType) == [
    "callField: string {.zero.}"
  ]

  doAssert getFieldsLists(MacroCallAliasType) == [
    "callField: bool {.zero.}"
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

  doAssert getCaseBranchValuesList(MyType[string]) == [
    "first: {true}",
    "second: {false}"
  ]

  doAssert getCaseBranchValuesList(DerivedFromRefType) == [
    "baseA: {kindA}"
  ]

  doAssert getCaseBranchValuesList(NestedCaseType) == [
    "innerKind: {kindA, kindB}",
    "nestedField: {1, 2}"
  ]

  doAssert getCaseBranchValuesList(ElseCaseType) == [
    "elseOfField: {1, 2}",
    "elseField: {0}",
    "elseOnlyField: {false, true}"
  ]

  doAssert getContainedValuesList(MyType[string]) == [
    "first: {true}",
    "second: {false}"
  ]

  doAssert getContainedValuesList(DerivedFromRefType) == [
    "baseA: {kindA}"
  ]

  doAssert getContainedValuesList(NestedCaseType) == [
    "innerKind: {kindA, kindB}",
    "nestedField: {1, 2}"
  ]

  doAssert getContainedValuesList(ElseCaseType) == [
    "elseOfField: {1, 2}",
    "elseField: {0}",
    "elseOnlyField: {false, true}"
  ]

  doAssert isCaseObject(MyType[string])
  doAssert compileTimeIsCaseObject(MyType[string])
  doAssert isCaseObject(RefBaseType)
  doAssert isCaseObject(ptr RefBaseType)
  doAssert isCaseObject(NestedCaseType)
  doAssert not isCaseObject(EmptyObject)
  doAssert not isCaseObject((int, string))
  doAssert not isCaseObject(PtrRefTupleType)
  doAssert not isCaseObject(int)
  doAssert not isCaseObject(seq[int])
  doAssert not isCaseObject(ref int)

  doAssert hasField(MyType[string], "myField")
  doAssert compileTimeHasField(MyType[string], "myField")
  doAssert hasField(MyType[string], "second")
  doAssert hasField(DerivedFromRefType, "baseA")
  doAssert hasField(PtrType, "genericBaseField")
  doAssert hasField(RefPtrType, "ptrField")
  doAssert hasField(TupleType, "tupleField")
  doAssert hasField(UnnamedTupleType, "Field1")
  doAssert hasField(RefTupleType, "refTupleField")
  doAssert hasField(QuotedType, "quotedField")
  doAssert hasField(QuotedType, "type")
  doAssert not hasField(MyType[string], "unknownField")
  doAssert not hasField(EmptyObject, "type")
  doAssert not hasField(seq[int], "len")
  doAssert not hasField(ref seq[int], "len")

  doAssert getIsTuple(TupleType)
  doAssert getIsTuple(UnnamedTupleType)
  doAssert getIsTuple(typeof((1, "a")))
  doAssert getIsTuple(GenericTupleType[int])
  doAssert getIsTuple(GenericTupleAliasType)
  doAssert not getIsTuple(RefTupleType)
  doAssert not getIsTuple(EmptyObject)
  doAssert not getIsTuple(int)

  doAssert typeHumaneName(FieldKind) == "FieldKind = enum\n  kindA, kindB"

  doAssert getEnumFieldsList(FieldKind) == @[
    "kindA: (0, \"kindA\")",
    "kindB: (1, \"kindB\")"
  ]

  doAssert getEnumFieldsList(HoleyKind) == @[
    "holeyA = 5: (5, \"holeyA\")",
    "holeyB = 20: (20, \"holeyB\")"
  ]

  doAssert getEnumFieldsList(HoleyKindAlias) == @[
    "holeyA = 5: (5, \"holeyA\")",
    "holeyB = 20: (20, \"holeyB\")"
  ]

  doAssert getEnumFieldsList(TemplateCallAliasKind) == @[
    "holeyA = 5: (5, \"holeyA\")",
    "holeyB = 20: (20, \"holeyB\")"
  ]

  doAssert getEnumFieldsList(TypeofAliasKind) == @[
    "holeyA = 5: (5, \"holeyA\")",
    "holeyB = 20: (20, \"holeyB\")"
  ]

  doAssert getEnumFieldsList(DescribedKind) == @[
    "describedA = \"first\": (0, \"first\")",
    "describedB: (1, \"describedB\")"
  ]

  doAssert getEnumFieldsList(ValuedKind) == @[
    "valuedA = -5: (-5, \"valuedA\")",
    "valuedB = (10, \"ten\"): (10, \"ten\")",
    "valuedC = \"val\" & \"ued\": (11, \"valued\")",
    "valuedD = 122: (122, \"valuedD\")",
    "valuedE = (127, \"e\"): (127, \"e\")",
    "valuedF: (128, \"valuedF\")"
  ]

  doAssert getEnumFieldsList(bool) == @[
    "false = 0: (0, \"false\")",
    "true = 1: (1, \"true\")"
  ]

  doAssert getTupleTypesList(UnnamedTupleType) == @["int", "string"]
  doAssert getTupleTypesList(TupleType) == @["int"]
  doAssert getTupleTypesList(GenericTupleType[string]) == @["string"]
  doAssert getTupleTypesList(GenericTupleAliasType) == @["int"]
  doAssert getTupleTypesList(AliasTupleType) == @[
    "ErrorType", "tuple[int, string]"]
  doAssert getTupleTypesList(tuple[]).len == 0
  when compiles(typeParamTupleTypesList(int)):
    doAssert false
  when compiles(typeParamTupleTypesList(void)):
    doAssert false

# Test for https://github.com/nim-lang/Nim/issues/26464
block:
  type
    CaseKind = enum
      caseA
      caseB

    StyleKind = enum
      styleA

    StyleCaseType = object
      case caseKind: CaseKind
      of caseA:
        styleKind: seq[StyleKind]
      of caseB:
        discard

  macro useFieldTypes(T: type): untyped =
    result = newStmtList()
    for field in recordFields(T.getTypeInst[1]):
      let typ = newTree(nnkTypeOfExpr, field.typ)
      result.add quote do:
        static: doAssert `typ` is typedesc

  useFieldTypes(StyleCaseType)

let myType = MyType[string](
  myField: "test", myGeneric: "test", kind: true, first: "test")

suite "Macros":
  test "pragmaName":
    const untypedPragmaLists = getPragmaLists:
      proc bareProc() {.zeroOrOne.} = discard
      proc emptyProc() {.zeroOrOne().} = discard
      proc colonProc() {.zeroOrOne: "colon".} = discard
      proc callProc() {.zeroOrOne("call").} = discard
      proc strLitProc() {.zeroOrOne"strLit".} = discard
      proc otherProc() {.zero, raises: [], gcsafe.} = discard
    check:
      untypedPragmaLists.names == @[
        "zeroOrOne", "zeroOrOne", "zeroOrOne", "zeroOrOne", "zeroOrOne",
        "zero", "raises", "gcsafe"]
      zeroOrOneProcs(getPragmaLists).names == untypedPragmaLists.names
      bindZeroOrOneProcs(getPragmaLists).names == untypedPragmaLists.names
      zeroOrOneProcs(getTypedPragmaLists).names == untypedPragmaLists.names

  test "findPragma":
    const untypedHasOverloadedPragma = hasOverloadedPragma:
      proc untypedProc() {.overloadedPragma.}
    check:
      untypedHasOverloadedPragma
      templateHasOverloadedPragma()
      bindHasOverloadedPragma()

  test "hasPragma":
    const untypedPragmaLists = getPragmaLists:
      proc bareProc() {.zeroOrOne.} = discard
      proc emptyProc() {.zeroOrOne().} = discard
      proc colonProc() {.zeroOrOne: "colon".} = discard
      proc callProc() {.zeroOrOne("call").} = discard
      proc strLitProc() {.zeroOrOne"strLit".} = discard
      proc otherProc() {.zero, raises: [], gcsafe.} = discard
    check:
      untypedPragmaLists.present == @[
        "zeroOrOne", "zeroOrOne", "zeroOrOne", "zeroOrOne", "zeroOrOne",
        "zero", "raises", "gcsafe"]
      zeroOrOneProcs(getPragmaLists).present == untypedPragmaLists.present
      bindZeroOrOneProcs(getPragmaLists).present == untypedPragmaLists.present
      zeroOrOneProcs(getTypedPragmaLists).present == untypedPragmaLists.present
      readBoundOverloadedPragmaPresence()
      zeroPragmaPresence(ReusedPragmaAliasType) == @[true, true, true, true]
      zeroPragmaPresence(MyType[string]) == @[true, true, true, true, true]
    const onePresence = getOnePresence:
      proc oneProc(a {.one("a").}, b: int, c {.one: "c".}: string)
    check onePresence == @[true, false, true]
    when compiles(block:
        macro undeclaredPragmaPresence(T: type): untyped =
          newLit recordFields(T)[0].hasPragma("undeclaredPragma")):
      check false

  test "readPragma":
    const untypedOverloadedPragmaValues = overloadedPragmaValues:
      proc bareProc() {.overloadedPragma.}
      proc colonProc() {.overloadedPragma: "colon".}
      proc callProc() {.overloadedPragma("call").}
      proc strLitProc() {.overloadedPragma"strLit".}
      proc otherProc() {.zero.}
    check:
      readBoundOverloadedPragma()
      untypedOverloadedPragmaValues ==
        @["overloadedPragma", "colon", "call", "strLit", ""]
      templateOverloadedPragmaValues() == untypedOverloadedPragmaValues
      bindOverloadedPragmaValues() == untypedOverloadedPragmaValues

  test "readPragmaValue":
    const untypedPragmaLists = getPragmaLists:
      proc bareProc() {.zeroOrOne.} = discard
      proc emptyProc() {.zeroOrOne().} = discard
      proc colonProc() {.zeroOrOne: "colon".} = discard
      proc callProc() {.zeroOrOne("call").} = discard
      proc strLitProc() {.zeroOrOne"strLit".} = discard
      proc otherProc() {.zero, raises: [], gcsafe.} = discard
    check:
      untypedPragmaLists.values == @["", "", "colon", "call", "strLit", ""]
      zeroOrOneProcs(getPragmaLists).values == untypedPragmaLists.values
      bindZeroOrOneProcs(getPragmaLists).values == untypedPragmaLists.values
      zeroOrOneProcs(getTypedPragmaLists).values == untypedPragmaLists.values
    const zeroOrOneValues = getZeroOrOneValues:
      proc oneProc(a {.zeroOrOne("a").}, b {.zeroOrOne.}: int, c: string)
    check zeroOrOneValues == @["a", "", ""]

  test "routineParams":
    const
      procParams = getParamsList:
        proc paramsProc(a, b {.zero.}: int, c: string = "c", d = 1): string
      funcParams = getParamsList:
        func paramsFunc(a, b {.zero.}: int, c: string = "c", d = 1): string
      methodParams = getParamsList:
        method paramsMethod(a, b {.zero.}: int, c: string = "c", d = 1): string
      iteratorParams = getParamsList:
        iterator paramsIterator(
            a, b {.zero.}: int, c: string = "c", d = 1): string
      templateParams = getParamsList:
        template paramsTemplate(
            a, b {.zero.}: int, c: string = "c", d = 1): string
      macroParams = getParamsList:
        macro paramsMacro(a, b {.zero.}: int, c: string = "c", d = 1): string
      doParams = getParamsList do (
          a, b {.zero.}: int, c: string = "c", d = 1) -> string:
        discard
      lambdaParams = getParamsList(
        proc (a, b {.zero.}: int, c: string = "c", d = 1): string = discard)
    check:
      procParams == @["a: int", "b: int {.zero.}", "c: string = \"c\"", "d = 1"]
      funcParams == procParams
      methodParams == procParams
      iteratorParams == procParams
      templateParams == procParams
      macroParams == procParams
      doParams == procParams
      lambdaParams == procParams
      templateParamsList() == procParams
      nestedParamsList() == procParams
    const oneValues = getOneValues:
      proc oneProc(a {.one("a").}, b: int, c {.zero.}: string)
    check oneValues == @["a", "", ""]

  test "isCaseObject":
    const isMyTypeCaseObject = isCaseObject(MyType[string])
    check:
      isMyTypeCaseObject
      isCaseObject(MyType[string])
      isCaseObject(ptr MyType[string])
      myType.type.isCaseObject
      genericIsCaseObject(MyType[string])
      macroIsCaseObject()
      not isCaseObject(GenericDerivedType[int])
      not isCaseObject(seq[int])
    when not isCaseObject(MyType[string]):
      check false

  test "hasField":
    const hasMyField = hasField(MyType[string], "myField")
    check:
      hasMyField
      hasField(MyType[string], "second")
      hasField(ref MyType[string], "myGeneric")
      myType.type.hasField("first")
      genericHasField(MyType[string], "kind")
      macroHasField()
      GenericDerivedType[int].hasField("genericBaseField")
      not hasField(MyType[string], "unknownField")
      not hasField(seq[int], "len")
    when not hasField(MyType[string], "myField"):
      check false

  test "field":
    var
      unnamedTuple: UnnamedTupleType
      namedTuple: TupleType
    unnamedTuple.field("Field0") = 1
    field(unnamedTuple, "Field1") = "unnamed"
    namedTuple.field("tupleField") = 2
    let unnamedTuplePtr = addr unnamedTuple
    check:
      unnamedTuple == (1, "unnamed")
      unnamedTuplePtr.field("Field0") == 1
      unnamedTuplePtr.field("FiEl_d0") == 1
      namedTuple.tupleField == 2
      myType.field("myField") == "test"

  test "identName":
    const
      untypedIdentNames = getIdentNames:
        proc identProc*(`type`, `quoted name` {.zero.}: int)
        type IdentType* {.zero.} = object
          identField* {.zero.}: int
        let identLet {.used.} = 0
      typedIdentNames = getTypedIdentNames:
        proc typedIdentProc(`type`, `quoted name` {.zero.}: int) = discard
    templateIdentNames(templateNames)
    nestedIdentNames(nestedNames)
    check:
      untypedIdentNames == @[
        "identProc", "type", "quotedname",
        "IdentType", "identField", "identLet"]
      templateNames == untypedIdentNames
      nestedNames == untypedIdentNames
      typedIdentNames == @["type", "quotedname"]
      templateTypedIdentNames() == typedIdentNames

  test "bracketExpr":
    const untypedBracketExprs = getBracketExprs:
      proc bracketProc(
          a: seq[int], b: GenericBaseType[seq[byte]], c: array[2, int],
          d: int, e: `[]`(seq, string))
    check:
      untypedBracketExprs == @[
        (true, "seq[int]"), (true, "GenericBaseType[seq[byte]]"),
        (true, "array[2, int]"), (false, "int"), (true, "seq[string]")]
      bracketExprProcs(getBracketExprs) == untypedBracketExprs
      bindBracketExprProcs(getBracketExprs) == untypedBracketExprs
      bracketExprProcs(getTypedBracketExprs) == untypedBracketExprs

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

      PublicType.hasCustomPragmaFixed(zero)
      PublicAliasType.hasCustomPragmaFixed(zero)
      GenericBaseType[int].hasCustomPragmaFixed(one)
      IntBaseType.hasCustomPragmaFixed(one)
      AliasBaseType.hasCustomPragmaFixed(one)
      AliasBaseType.hasCustomPragmaFixed(zero)
      CallGenericType[int].hasCustomPragmaFixed(one)
      TemplateCallAliasType.hasCustomPragmaFixed(one)
      DotTemplateCallAliasType.hasCustomPragmaFixed(one)
      MacroCallAliasType.hasCustomPragmaFixed(one)
      not EmptyObject.hasCustomPragmaFixed(zero)
      not (int, string).hasCustomPragmaFixed(zero)
      not (ref GenericBaseType[int]).hasCustomPragmaFixed(one)
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

      PublicType.getCustomPragmaFixed(zero).isNil
      PublicType.getCustomPragmaFixed(one) == "public"
      PublicAliasType.getCustomPragmaFixed(one) == "public"
      GenericBaseType[int].getCustomPragmaFixed(one) == "generic"
      IntBaseType.getCustomPragmaFixed(one) == "generic"
      AliasBaseType.getCustomPragmaFixed(one) == "generic"
      CallGenericType[int].getCustomPragmaFixed(one) == "call"
      TemplateCallAliasType.getCustomPragmaFixed(one) == "call"
      DotTemplateCallAliasType.getCustomPragmaFixed(one) == "call"
      MacroCallAliasType.getCustomPragmaFixed(one) == "call"
      EmptyObject.getCustomPragmaFixed(zero).isNil
      (int, string).getCustomPragmaFixed(zero).isNil
      (ref GenericBaseType[int]).getCustomPragmaFixed(one).isNil
    when compiles(MyType[string].getCustomPragmaFixed("unknownField", zero)):
      check false
