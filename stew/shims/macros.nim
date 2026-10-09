{.push raises: [].}

import
  std/[hashes, macrocache, macros, tables, typetraits]

export
  macros

type
  FieldDescription* = object
    name*: NimNode
    isPublic*: bool
    isDiscriminator*: bool
    typ*: NimNode
    pragmas*: NimNode
    caseField*: NimNode
    caseBranch*: NimNode

const
  nnkPragmaCallKinds = {nnkExprColonExpr, nnkCall, nnkCallStrLit}

func hash*(x: LineInfo): Hash =
  !$(hash(x.filename) !& hash(x.line) !& hash(x.column))

var
  # Please note that we are storing NimNode here in order to
  # incur the code rendering cost only on a successful compilation.
  macroLocations {.compileTime.} = newSeq[LineInfo]()
  macroOutputs {.compileTime.} = newSeq[NimNode]()

proc writeMacroResultsNow* {.compileTime, raises: [IOError].} =
  var files = initTable[string, NimNode]()

  proc addToFile(file: var NimNode, location: LineInfo, macroOutput: NimNode) =
    if file == nil:
      file = newNimNode(nnkStmtList, macroOutput)

    file.add newCommentStmtNode("Generated at line " & $location.line)
    file.add macroOutput

  for i in 0 ..< macroLocations.len:
    addToFile files.mgetOrPut(macroLocations[i].filename, nil),
              macroLocations[i], macroOutputs[i]

  for name, contents in files:
    let targetFile = name & ".generated.nim"
    writeFile(targetFile, repr(contents))
    hint "Wrote macro output to " & targetFile, contents

proc storeMacroResult*(callSite: LineInfo,
                       macroResult: NimNode,
                       writeOutputImmediately = false) {.raises: [IOError].} =
  macroLocations.add callSite
  macroOutputs.add macroResult
  if writeOutputImmediately:
    # echo macroResult.repr
    writeMacroResultsNow()

proc storeMacroResult*(macroResult: NimNode, writeOutputImmediately = false) {.raises: [IOError].} =
  let usageSite = callsite().lineInfoObj
  storeMacroResult(usageSite, macroResult, writeOutputImmediately)

macro dumpMacroResults*: untyped =
  try:
    writeMacroResultsNow()
  except IOError as exc:
    doAssert(false, exc.msg)

func findPragma*(pragmas: NimNode, pragmaSym: NimNode): NimNode =
  for p in pragmas:
    if p.kind in {nnkSym, nnkIdent} and eqIdent(p, pragmaSym):
      return p
    if p.kind in nnkPragmaCallKinds and p.len > 0 and eqIdent(p[0], pragmaSym):
      return p

func isTuple*(typ: NimNode): bool =
  typ.kind == nnkBracketExpr and
  typ[0].kind == nnkSym and
  eqIdent(typ[0], "tuple")

macro isTuple*(T: type): untyped =
  newLit(isTuple(getType(T)[1]))

func skipRef*(typ: NimNode): NimNode =
  if typ.kind == nnkBracketExpr and eqIdent(typ[0], "ref"): typ[1] else: typ

func skipPtr*(typ: NimNode): NimNode =
  if typ.kind == nnkBracketExpr and eqIdent(typ[0], "ptr"): typ[1] else: typ

template readPragma*(
    field: FieldDescription, pragmaName: static string): NimNode =
  let p = findPragma(field.pragmas, bindSym(pragmaName))
  if p != nil and p.len == 2: p[1] else: p

func collectFieldsFromRecList(
    fields: var seq[FieldDescription], n: NimNode,
    parentCaseField: NimNode = nil, parentCaseBranch: NimNode = nil,
    isDiscriminator = false) =
  case n.kind
  of nnkRecList:
    for entry in n:
      collectFieldsFromRecList fields, entry,
                               parentCaseField, parentCaseBranch
  of nnkRecWhen:
    for branch in n:
      case branch.kind:
      of nnkElifBranch:
        collectFieldsFromRecList fields, branch[1],
                                 parentCaseField, parentCaseBranch
      of nnkElse:
        collectFieldsFromRecList fields, branch[0],
                                 parentCaseField, parentCaseBranch
      else:
        doAssert false

  of nnkRecCase:
    collectFieldsFromRecList fields, n[0],
                             parentCaseField,
                             parentCaseBranch,
                             isDiscriminator = true

    for i in 1 ..< n.len:
      let branch = n[i]
      case branch.kind
      of nnkOfBranch:
        collectFieldsFromRecList fields, branch[^1], n[0], branch
      of nnkElse:
        collectFieldsFromRecList fields, branch[0], n[0], branch
      else:
        doAssert false

  of nnkIdentDefs:
    let fieldType = n[^2]
    for i in 0 ..< n.len - 2:
      var field: FieldDescription
      field.name = n[i]
      field.typ = fieldType
      field.caseField = parentCaseField
      field.caseBranch = parentCaseBranch
      field.isDiscriminator = isDiscriminator

      if field.name.kind == nnkPragmaExpr:
        field.pragmas = field.name[1]
        field.name = field.name[0]

      if field.name.kind == nnkPostfix:
        field.isPublic = true
        field.name = field.name[1]

      fields.add field

  of nnkSym:
    fields.add FieldDescription(
      name: n,
      typ: getType(n),
      caseField: parentCaseField,
      caseBranch: parentCaseBranch,
      isDiscriminator: isDiscriminator)

  of nnkNilLit, nnkDiscardStmt, nnkCommentStmt, nnkEmpty:
    discard

  else:
    raiseAssert "Unexpected nodes in recordFields:\n" & n.treeRepr

func collectFieldsFromTuple(fields: var seq[FieldDescription], n: NimNode) =
  if n.kind == nnkTupleConstr:
    for i in 0 ..< n.len:
      fields.add FieldDescription(typ: n[i], name: ident("Field" & $i))
  else:
    for entry in n:
      collectFieldsFromRecList fields, entry

func objectDefinition(typeInst: NimNode): NimNode =
  var typeSym = if typeInst.kind == nnkBracketExpr: typeInst[0] else: typeInst
  while typeSym.kind == nnkSym:
    let typeDef = getImpl(typeSym)
    if typeDef.kind != nnkTypeDef:
      break
    var body = typeDef[2]
    if body.kind in {nnkRefTy, nnkPtrTy}:
      body = body[0]
    case body.kind
    of nnkObjectTy:
      return body
    of nnkSym:
      typeSym = body
    of nnkBracketExpr:
      typeSym = body[0]
    else:
      break
  nil

func collectFieldsInHierarchy(
    fields: var seq[FieldDescription], objectType: NimNode) =
  var objectType = objectType

  objectType.expectKind {nnkObjectTy, nnkRefTy, nnkPtrTy}

  if objectType.kind in {nnkRefTy, nnkPtrTy}:
    objectType = objectType[0]

  objectType.expectKind nnkObjectTy

  let baseType = objectType[1]
  if baseType.kind != nnkEmpty:
    baseType.expectKind nnkOfInherit
    let baseDef = baseType[0].objectDefinition
    if baseDef == nil:
      macros.error("object type expected", baseType[0])
    collectFieldsInHierarchy fields, baseDef

  let recList = objectType[2]
  collectFieldsFromRecList fields, recList

func isSameName(defName, name: NimNode): bool =
  if defName.kind == nnkAccQuoted and defName.len > 1:
    eqIdent($defName, name)  # https://github.com/nim-lang/Nim/issues/26383
  else:
    eqIdent(defName, name)

func caseFieldName*(field: FieldDescription): NimNode =
  if field.caseField == nil:
    return nil
  var name = field.caseField[0]
  if name.kind == nnkPragmaExpr:
    name = name[0]
  if name.kind == nnkPostfix:
    name = name[1]
  name

func isSameCaseField(a, b: FieldDescription): bool =
  let
    aName = a.caseFieldName
    bName = b.caseFieldName
  if aName == nil or bName == nil:
    aName == nil and bName == nil
  else:
    aName.isSameName(bName)

func isDefinitionOf(defField, field: FieldDescription): bool =
  # The compiler has no link from a field symbol back to its definition node,
  # select the correct definition on a best-effort basis.
  # https://github.com/nim-lang/Nim/issues/26373
  defField.name.isSameName(field.name) and
  defField.isSameCaseField(field) and
  defField.name.lineInfoObj == field.name.lineInfoObj

func definedField(
    defFields: seq[FieldDescription],
    field: FieldDescription): FieldDescription =
  var match = -1
  template matchField: FieldDescription = defFields[match]
  for i in 0 ..< defFields.len:
    template defField: FieldDescription = defFields[i]
    if defField.isDefinitionOf(field):
      if match == -1:
        match = i
      elif defField.isPublic != matchField.isPublic or
          defField.pragmas != matchField.pragmas or
          defField.caseBranch != matchField.caseBranch:
        macros.error("ambiguous definition of field " & $field.name, field.name)
  if match == -1:
    macros.error("no definition found for field " & $field.name, field.name)
  var defField = matchField
  defField.typ = field.typ
  defField

func areAllFieldsDefined(def: NimNode, fields: seq[FieldDescription]): bool =
  var defFields: seq[FieldDescription]
  collectFieldsFromRecList defFields, def[2]
  for i in 0 ..< fields.len:
    var found = false
    for j in 0 ..< defFields.len:
      if defFields[j].isDefinitionOf(fields[i]):
        found = true
        break
    if not found:
      return false
  true

func aliasedDefinition(node: NimNode, fields: seq[FieldDescription]): NimNode =
  let def = node.objectDefinition
  if def != nil:
    return if def.areAllFieldsDefined(fields): def else: nil
  if node.kind == nnkSym:
    let typeDef = node.getImpl
    if typeDef.kind == nnkTypeDef:
      return typeDef[2].aliasedDefinition(fields)
    return nil
  for child in node:
    let def = child.aliasedDefinition(fields)
    if def != nil:
      return def
  nil

func collectFieldsFromType(
    fields: var seq[FieldDescription], typeInst, typeImpl: NimNode) =
  var typeImpl = typeImpl
  while typeImpl.kind in {nnkRefTy, nnkPtrTy}:
    typeImpl = typeImpl[0].getTypeImpl
  if typeImpl.kind in {nnkTupleTy, nnkTupleConstr}:
    collectFieldsFromTuple(fields, typeImpl)
    return
  typeImpl.expectKind nnkObjectTy

  let baseType = typeImpl[1]
  if baseType.kind != nnkEmpty:
    baseType.expectKind nnkOfInherit
    collectFieldsFromType fields, baseType[0], baseType[0].getTypeImpl

  var implFields: seq[FieldDescription]
  collectFieldsFromRecList implFields, typeImpl[2]

  var def = typeInst.objectDefinition
  if def == nil:
    def = typeImpl.getTypeInst.objectDefinition
  if def == nil:
    def = typeInst.aliasedDefinition(implFields)
  if def == nil:
    # https://github.com/nim-lang/Nim/issues/22937
    warning("definition of " & typeInst.repr &
      " not found, its field pragmas are ignored", typeInst)
    for i in 0 ..< implFields.len:
      var field = implFields[i]
      field.isPublic = field.name.isExported
      fields.add field
    return

  var defFields: seq[FieldDescription]
  collectFieldsFromRecList defFields, def[2]
  for i in 0 ..< implFields.len:
    fields.add defFields.definedField(implFields[i])

func recordFields*(typ: NimNode): seq[FieldDescription] =
  var fields: seq[FieldDescription]
  if typ.isTuple:
    for i in 1 ..< typ.len:
      fields.add FieldDescription(
        typ: typ[i], name: ident("Field" & $(i - 1)))
    return fields

  case typ.kind
  of nnkSym, nnkBracketExpr:
    let
      typeInst = skipPtr skipRef typ
      typeImpl = typeInst.getTypeImpl
    if typeImpl.typeKind == ntyTypeDesc:
      return recordFields(typ.getTypeInst[1])
    collectFieldsFromType(fields, typeInst, typeImpl)
    return fields
  of nnkRefTy, nnkPtrTy:
    if typ[0].kind in {nnkSym, nnkBracketExpr}:
      return recordFields(typ[0])
  of nnkObjectTy:
    let recList = typ[2]
    if recList.kind == nnkRecList and recList.len > 0:
      var firstField = recList[0]
      if firstField.kind == nnkRecCase:
        firstField = firstField[0]
      if firstField.kind == nnkIdentDefs and firstField[0].kind == nnkSym:
        collectFieldsFromType(fields, typ.getTypeInst, typ)
        return fields
    elif typ[1].kind == nnkOfInherit:
      return recordFields(typ[1][0])
  of nnkTypeDef:
    var name = typ[0]
    if name.kind == nnkPragmaExpr:
      name = name[0]
    if name.kind == nnkPostfix:
      name = name[1]
    if name.kind == nnkSym and typ[1].kind == nnkEmpty and
        name.getImpl.kind == nnkTypeDef:
      # https://github.com/nim-lang/Nim/issues/26399
      collectFieldsFromType(fields, name, name.getTypeInst.getTypeImpl)
      return fields
  else:
    discard

  let objectType = case typ.kind
    of nnkObjectTy, nnkRefTy, nnkPtrTy, nnkTupleTy, nnkTupleConstr: typ
    of nnkTypeDef: typ[2]
    else:
      macros.error("object or tuple type expected", typ)

  if objectType.kind in {nnkTupleTy, nnkTupleConstr}:
    collectFieldsFromTuple(fields, objectType)
  else:
    collectFieldsInHierarchy(fields, objectType)
  fields

macro field*(obj: typed, fieldName: static string): untyped =
  newDotExpr(obj, ident fieldName)

func skipPragma*(n: NimNode): NimNode =
  if n.kind == nnkPragmaExpr: n[0]
  else: n

func fieldPragmas(typedescNode, typ: NimNode): NimNode =
  let cache = CacheSeq("stew.shims.macros.fieldPragmas." & typ.repr)
  for entry in cache:
    if sameType(typedescNode, entry[0]):
      return entry[1]

  # Index into fields rather than iterate across elements to work around
  # https://github.com/nim-lang/Nim/issues/26273
  let
    fields = recordFields(typ)
    res = newNimNode(nnkBracket)
  for i in 0 ..< fields.len:
    let
      name = fields[i].name
      p = if fields[i].pragmas == nil: newEmptyNode() else: fields[i].pragmas
    res.add quote do: (`name`, `p`)
  cache.add quote do: (`typedescNode`, `res`)
  res

func getPragma(
    typedescNode: NimNode, lookedUpField: string, pragma: NimNode): NimNode =
  let typ = getType(typedescNode)[1]
  if isTuple(typ):
    return nil

  let fieldName = ident(lookedUpField)
  for field in fieldPragmas(typedescNode, typ):
    if field[0].isSameName(fieldName):
      return field[1].findPragma(pragma).copyNimTree

  error "The type " & $typ & " doesn't have a field named " & lookedUpField

macro getCustomPragmaFixed*(T: type, field: static string, pragma: typed{nkSym}): untyped =
  let p = getPragma(T, field, pragma)
  if p == nil or p.len == 0:
    return nil
  if p.len == 2:
    return p[1]

  let
    def = p[0].getImpl[3]
    args = newTree(nnkPar)
  for i in 1 ..< def.len:
    let key = def[i][0]
    let val = p[i]
    args.add newTree(nnkExprColonExpr, key, val)
  args

macro hasCustomPragmaFixed*(T: type, field: static string, pragma: typed{nkSym}): untyped =
  newLit(getPragma(T, field, pragma) != nil)

func humaneTypeName*(typedescNode: NimNode): string =
  var typ = getType(typedescNode)[1]
  if typ.kind != nnkBracketExpr:
    let typeDef = typ.getImpl
    if typeDef != nil and typeDef.kind notin {nnkEmpty, nnkNilLit}:
      typ = typeDef

  repr(typ)

macro inspectType*(T: typed): untyped =
  echo "Inspect type: ", humaneTypeName(T)

# FIXED NewLit

func newLitFixed*(c: char): NimNode {.compileTime.} =
  ## Produces a new character literal node.
  result = newNimNode(nnkCharLit)
  result.intVal = ord(c)

func newLitFixed*(i: int): NimNode {.compileTime.} =
  ## Produces a new integer literal node.
  result = newNimNode(nnkIntLit)
  result.intVal = i

func newLitFixed*(i: int8): NimNode {.compileTime.} =
  ## Produces a new integer literal node.
  result = newNimNode(nnkInt8Lit)
  result.intVal = i

func newLitFixed*(i: int16): NimNode {.compileTime.} =
  ## Produces a new integer literal node.
  result = newNimNode(nnkInt16Lit)
  result.intVal = i

func newLitFixed*(i: int32): NimNode {.compileTime.} =
  ## Produces a new integer literal node.
  result = newNimNode(nnkInt32Lit)
  result.intVal = i

func newLitFixed*(i: int64): NimNode {.compileTime.} =
  ## Produces a new integer literal node.
  result = newNimNode(nnkInt64Lit)
  result.intVal = i

func newLitFixed*(i: uint): NimNode {.compileTime.} =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUIntLit)
  result.intVal = BiggestInt(i)

func newLitFixed*(i: uint8): NimNode {.compileTime.} =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt8Lit)
  result.intVal = BiggestInt(i)

func newLitFixed*(i: uint16): NimNode {.compileTime.} =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt16Lit)
  result.intVal = BiggestInt(i)

func newLitFixed*(i: uint32): NimNode {.compileTime.} =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt32Lit)
  result.intVal = BiggestInt(i)

func newLitFixed*(i: uint64): NimNode {.compileTime.} =
  ## Produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt64Lit)
  result.intVal = BiggestInt(i)

func newLitFixed*(b: bool): NimNode {.compileTime.} =
  ## Produces a new boolean literal node.
  result = if b: bindSym"true" else: bindSym"false"

func newLitFixed*(s: string): NimNode {.compileTime.} =
  ## Produces a new string literal node.
  result = newNimNode(nnkStrLit)
  result.strVal = s

when false:
  # the float type is not really a distinct type as described in https://github.com/nim-lang/Nim/issues/5875
  proc newLitFixed*(f: float): NimNode {.compileTime.} =
    ## Produces a new float literal node.
    result = newNimNode(nnkFloatLit)
    result.floatVal = f

func newLitFixed*(f: float32): NimNode {.compileTime.} =
  ## Produces a new float literal node.
  result = newNimNode(nnkFloat32Lit)
  result.floatVal = f

func newLitFixed*(f: float64): NimNode {.compileTime.} =
  ## Produces a new float literal node.
  result = newNimNode(nnkFloat64Lit)
  result.floatVal = f

when declared(float128):
  proc newLitFixed*(f: float128): NimNode {.compileTime.} =
    ## Produces a new float literal node.
    result = newNimNode(nnkFloat128Lit)
    result.floatVal = f

func newLitFixed*(arg: enum): NimNode {.compileTime.} =
  result = newCall(
    arg.type.getTypeInst[1],
    newLitFixed(int(arg))
  )

func newLitFixed*[N,T](arg: array[N,T]): NimNode {.compileTime.}
func newLitFixed*[T](arg: seq[T]): NimNode {.compileTime.}
func newLitFixed*[T](s: set[T]): NimNode {.compileTime.}
func newLitFixed*(arg: tuple): NimNode {.compileTime.}

func newLitFixed*(arg: object): NimNode {.compileTime.} =
  result = nnkObjConstr.newTree(arg.type.getTypeInst[1])
  for a, b in arg.fieldPairs:
    result.add nnkExprColonExpr.newTree( newIdentNode(a), newLitFixed(b) )

func newLitFixed*(arg: ref object): NimNode {.compileTime.} =
  ## produces a new ref type literal node.
  result = nnkObjConstr.newTree(arg.type.getTypeInst[1])
  for a, b in fieldPairs(arg[]):
    result.add nnkExprColonExpr.newTree(newIdentNode(a), newLitFixed(b))

func newLitFixed*[N,T](arg: array[N,T]): NimNode {.compileTime.} =
  result = nnkBracket.newTree
  for x in arg:
    result.add newLitFixed(x)

func newLitFixed*[T](arg: seq[T]): NimNode {.compileTime.} =
  let bracket = nnkBracket.newTree
  for x in arg:
    bracket.add newLitFixed(x)
  result = nnkPrefix.newTree(
    bindSym"@",
    bracket
  )
  if arg.len == 0:
    # add type cast for empty seq
    var typ = getTypeInst(typeof(arg))[1]
    result = newCall(typ,result)

func newLitFixed*[T](s: set[T]): NimNode {.compileTime.} =
  result = nnkCurly.newTree
  for x in s:
    result.add newLitFixed(x)

func newLitFixed*(arg: tuple): NimNode {.compileTime.} =
  result = nnkPar.newTree
  for a,b in arg.fieldPairs:
    result.add nnkExprColonExpr.newTree(newIdentNode(a), newLitFixed(b))

func newLitFixed*(arg: distinct): NimNode {.compileTime.} =
  result = newLitFixed distinctBase(arg)
  var typ = getTypeInst(typeof(arg))[1]
  result = newCall(typ,result)

iterator typedParams*(n: NimNode, skip = 0): (NimNode, NimNode) =
  let params = n[3]
  for i in (1 + skip) ..< params.len:
    let paramNodes = params[i]
    let paramType = paramNodes[^2]

    for j in 0 ..< paramNodes.len - 2:
      yield (skipPragma paramNodes[j], paramType)

iterator baseTypes*(exceptionType: NimNode): NimNode =
  var typ = exceptionType
  while typ != nil:
    let impl = getImpl(typ)
    if impl.len != 3 or impl[2].kind != nnkObjectTy:
      break

    let objType = impl[2]
    if objType[1].kind != nnkOfInherit:
      break

    typ = objType[1][0]
    yield typ

macro unpackArgs*(callee: untyped, args: untyped): untyped =
  const ArgKind = nnkArgList

  result = newCall(callee)
  for arg in args:
    let arg = if arg.kind == nnkHiddenStdConv: arg[1]
              else: arg
    if arg.kind == ArgKind:
      for subarg in arg:
        result.add subarg
    else:
      result.add arg

template genExpr*(treeType: NimNodeKind, body: untyped): untyped =
  iterator generator: NimNode = body

  macro payload: untyped =
    result = newTree(treeType)
    for node in generator():
      result.add node

  payload()

template genStmtList*(body: untyped) =
  iterator generator: NimNode = body

  macro payload: untyped =
    result = newStmtList()
    for node in generator():
      result.add node

  payload()

template genSimpleExpr*(body: untyped): untyped =
  macro payload: untyped = body
  payload()

{.pop.}
