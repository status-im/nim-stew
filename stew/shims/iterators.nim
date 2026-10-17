# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import ./macros

func expectNoContinue(n: NimNode) =
  if n.kind == nnkContinueStmt:
    macros.error("'continue' not supported in a 'fieldTypePairs' loop", n)
  if n.kind notin {nnkForStmt, nnkWhileStmt}:
    for child in n:
      expectNoContinue(child)

macro fieldTypePairsLoop(loop: typed): untyped =
  loop.expectKind nnkWhileStmt
  loop[1].expectNoContinue()
  loop

func fieldTypePair(name, field, nameVar, typeVar, body: NimNode): NimNode =
  let stmts = newStmtList()
  if not eqIdent(nameVar, "_"):
    stmts.add newConstStmt(nameVar, name)
  if not eqIdent(typeVar, "_"):
    stmts.add quote do:
      type `typeVar` = typeof(`field`)
  stmts.add body.copyNimTree
  newIfStmt((newLit(true), stmts))

func addFieldTypePairs(stmts, n, obj, nameVar, typeVar, body: NimNode) =
  case n.kind
  of nnkRecList, nnkTupleTy:
    for entry in n:
      stmts.addFieldTypePairs(entry, obj, nameVar, typeVar, body)
  of nnkRecCase:
    stmts.addFieldTypePairs(n[0], obj, nameVar, typeVar, body)
    for i in 1 ..< n.len:
      if n.caseBranchValues(i).containsOrdinal(0):
        stmts.addFieldTypePairs(n[i][^1], obj, nameVar, typeVar, body)
  of nnkIdentDefs:
    for i in 0 ..< n.len - 2:
      stmts.add fieldTypePair(
        newLit($n[i]), newDotExpr(obj, n[i]), nameVar, typeVar, body)
  else:
    discard

macro fieldTypePairsImpl(T: type, nameVar, typeVar, body: untyped): untyped =
  var typ = T.getTypeInst[1]
  if typ.isSink:
    typ = typ[1]
  let
    obj = quote do: default(ptr `typ`)[]
    stmts = newStmtList()
  var typeImpl = typ.getTypeImpl
  while true:
    while typeImpl.kind in {nnkRefTy, nnkPtrTy}:
      typeImpl = typeImpl[0].getTypeImpl
    case typeImpl.kind
    of nnkTupleConstr:
      for i in 0 ..< typeImpl.len:
        stmts.add fieldTypePair(newLit("Field" & $i),
          nnkBracketExpr.newTree(obj, newLit(i)), nameVar, typeVar, body)
      break
    of nnkTupleTy:
      stmts.addFieldTypePairs(typeImpl, obj, nameVar, typeVar, body)
      break
    of nnkObjectTy:
      stmts.addFieldTypePairs(typeImpl[2], obj, nameVar, typeVar, body)
      if typeImpl[1].kind != nnkOfInherit:
        break
      typeImpl = typeImpl[1][0].getTypeImpl
    else:
      macros.error("object or tuple type expected", T)
  if stmts.len == 0:
    # https://github.com/nim-lang/Nim/issues/26487
    return newStmtList()
  stmts.add nnkBreakStmt.newTree(newEmptyNode())
  newCall(bindSym"fieldTypePairsLoop",
    nnkWhileStmt.newTree(newLit(true), stmts))

macro fieldTypePairs*(x: ForLoopStmt): untyped =
  if x.len != 4:
    macros.error("wrong number of variables", x)
  x[^2].expectLen 2
  newCall(bindSym"fieldTypePairsImpl", x[^2][1], x[0], x[1], x[^1])
