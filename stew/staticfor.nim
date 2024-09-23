# stew
# Copyright (c) 2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

import std/macros

proc replaceNodes(ast: NimNode, what: NimNode, by: NimNode): NimNode =
  # Replace "what" ident node by "by"
  proc inspect(node: NimNode): NimNode =
    case node.kind:
    of {nnkIdent, nnkSym}:
      if node.eqIdent(what):
        by
      else:
        node
    of nnkEmpty, nnkLiterals:
      node
    else:
      let rTree = newNimNode(node.kind, lineInfoFrom = node)
      for child in node:
        rTree.add inspect(child)
      rTree
  inspect(ast)

macro staticFor*(idx: untyped{nkIdent}, slice: static Slice[int], body: untyped): untyped =
  ## Unrolled `for` loop over the given range:
  ##
  ## ```nim
  ## staticFor(i, 0..<2):
  ##   echo default(array[i, byte])
  ## ```
  result = newNimNode(nnkStmtList, lineInfoFrom = body)
  for i in slice:
    result.add nnkBlockStmt.newTree(
      ident(":staticFor" & $idx & $i),
      body.replaceNodes(idx, newLit i)
    )
