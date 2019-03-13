import
  macros

export
  macros

type
  FieldDescription* = object
    name*: NimNode
    isPublic*: bool
    typ*: NimNode
    pragmas*: NimNode
    caseField*: NimNode
    caseBranch*: NimNode

const
  nnkPragmaCallKinds = {nnkExprColonExpr, nnkCall, nnkCallStrLit}

proc findPragma*(pragmas: NimNode, pragmaSym: NimNode): NimNode =
  for p in pragmas:
    if p.kind == nnkSym and p == pragmaSym:
      return p
    if p.kind in nnkPragmaCallKinds and p.len > 0 and p[0].kind == nnkSym and p[0] == pragmaSym:
      return p

iterator recordFields*(typeImpl: NimNode): FieldDescription =
  # TODO: This doesn't support inheritance yet
  let
    objectType = typeImpl[2]
    recList = objectType[2]

  type
    RecursionStackItem = tuple
      currentNode: NimNode
      currentChildItem: int
      parentCaseField: NimNode
      parentCaseBranch: NimNode

  if recList.len > 0:
    var traversalStack: seq[RecursionStackItem] = @[
      (recList, 0, NimNode(nil), NimNode(nil))
    ]

    template recuseInto(childNode: NimNode,
                      currentCaseField: NimNode = nil,
                      currentCaseBranch: NimNode = nil) =
      traversalStack.add (childNode, 0, currentCaseField, currentCaseBranch)

    while true:
      doAssert traversalStack.len > 0

      var stackTop = traversalStack[^1]
      let recList = stackTop.currentNode
      let idx = stackTop.currentChildItem
      let n = recList[idx]
      inc traversalStack[^1].currentChildItem

      if idx == recList.len - 1:
        discard traversalStack.pop

      case n.kind
      of nnkRecWhen:
        for i in countdown(n.len - 1, 0):
          let branch = n[i]
          case branch.kind:
          of nnkElifBranch:
            recuseInto branch[1]
          of nnkElse:
            recuseInto branch[0]
          else:
            doAssert false

        continue

      of nnkRecCase:
        doAssert n.len > 0
        for i in countdown(n.len - 1, 1):
          let branch = n[i]
          case branch.kind
          of nnkOfBranch:
            recuseInto branch[^1], n[0], branch
          of nnkElse:
            recuseInto branch[0], n[0], branch
          else:
            doAssert false

        recuseInto newTree(nnkRecCase, n[0])
        continue

      of nnkIdentDefs:
        let fieldType = n[^2]
        for i in 0 ..< n.len - 2:
          var field: FieldDescription
          field.name = n[i]
          field.typ = fieldType
          field.caseField = stackTop.parentCaseField
          field.caseBranch = stackTop.parentCaseBranch

          if field.name.kind == nnkPragmaExpr:
            field.pragmas = field.name[1]
            field.name = field.name[0]

          if field.name.kind == nnkPostfix:
            field.isPublic = true
            field.name = field.name[1]

          yield field

      of nnkNilLit, nnkDiscardStmt, nnkCommentStmt, nnkEmpty:
        discard

      else:
        doAssert false

      if traversalStack.len == 0: break

proc skipPragma*(n: NimNode): NimNode =
  if n.kind == nnkPragmaExpr: n[0]
  else: n

# FIXED NewLit

proc newLitFixed*(c: char): NimNode {.compileTime.} =
  ## produces a new character literal node.
  result = newNimNode(nnkCharLit)
  result.intVal = ord(c)

proc newLitFixed*(i: int): NimNode {.compileTime.} =
  ## produces a new integer literal node.
  result = newNimNode(nnkIntLit)
  result.intVal = i

proc newLitFixed*(i: int8): NimNode {.compileTime.} =
  ## produces a new integer literal node.
  result = newNimNode(nnkInt8Lit)
  result.intVal = i

proc newLitFixed*(i: int16): NimNode {.compileTime.} =
  ## produces a new integer literal node.
  result = newNimNode(nnkInt16Lit)
  result.intVal = i

proc newLitFixed*(i: int32): NimNode {.compileTime.} =
  ## produces a new integer literal node.
  result = newNimNode(nnkInt32Lit)
  result.intVal = i

proc newLitFixed*(i: int64): NimNode {.compileTime.} =
  ## produces a new integer literal node.
  result = newNimNode(nnkInt64Lit)
  result.intVal = i

proc newLitFixed*(i: uint): NimNode {.compileTime.} =
  ## produces a new unsigned integer literal node.
  result = newNimNode(nnkUIntLit)
  result.intVal = BiggestInt(i)

proc newLitFixed*(i: uint8): NimNode {.compileTime.} =
  ## produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt8Lit)
  result.intVal = BiggestInt(i)

proc newLitFixed*(i: uint16): NimNode {.compileTime.} =
  ## produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt16Lit)
  result.intVal = BiggestInt(i)

proc newLitFixed*(i: uint32): NimNode {.compileTime.} =
  ## produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt32Lit)
  result.intVal = BiggestInt(i)

proc newLitFixed*(i: uint64): NimNode {.compileTime.} =
  ## produces a new unsigned integer literal node.
  result = newNimNode(nnkUInt64Lit)
  result.intVal = BiggestInt(i)

proc newLitFixed*(b: bool): NimNode {.compileTime.} =
  ## produces a new boolean literal node.
  result = if b: bindSym"true" else: bindSym"false"

proc newLitFixed*(f: float32): NimNode {.compileTime.} =
  ## produces a new float literal node.
  result = newNimNode(nnkFloat32Lit)
  result.floatVal = f

proc newLitFixed*(f: float64): NimNode {.compileTime.} =
  ## produces a new float literal node.
  result = newNimNode(nnkFloat64Lit)
  result.floatVal = f

proc newLitFixed*(s: string): NimNode {.compileTime.} =
  ## produces a new string literal node.
  result = newNimNode(nnkStrLit)
  result.strVal = s

proc newLitFixed*[N,T](arg: array[N,T]): NimNode {.compileTime.}
proc newLitFixed*[T](arg: seq[T]): NimNode {.compileTime.}
proc newLitFixed*(arg: tuple): NimNode {.compileTime.}

proc newLitFixed*(arg: object): NimNode {.compileTime.} =
  result = nnkObjConstr.newTree(arg.type.getTypeInst[1])
  for a, b in arg.fieldPairs:
    result.add nnkExprColonExpr.newTree( newIdentNode(a), newLitFixed(b) )

proc newLitFixed*[N,T](arg: array[N,T]): NimNode {.compileTime.} =
  result = nnkBracket.newTree
  for x in arg:
    result.add newLitFixed(x)

proc newLitFixed*[T](arg: seq[T]): NimNode {.compileTime.} =
  var bracket = nnkBracket.newTree
  for x in arg:
    bracket.add newLitFixed(x)

  result = nnkCall.newTree(
    nnkBracketExpr.newTree(
      nnkAccQuoted.newTree( bindSym"@" ),
      getTypeInst( bindSym"T" )
    ),
    bracket
  )

proc newLitFixed*(arg: tuple): NimNode {.compileTime.} =
  result = nnkPar.newTree
  for a,b in arg.fieldPairs:
    result.add nnkExprColonExpr.newTree(newIdentNode(a), newLitFixed(b))

iterator typedParams*(n: NimNode, skip = 0): (NimNode, NimNode) =
  for i in (1 + skip) ..< n.params.len:
    let paramNodes = n.params[i]
    let paramType = paramNodes[^2]

    for j in 0 ..< paramNodes.len - 2:
      yield (paramNodes[j], paramType)

