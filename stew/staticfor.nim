import std/macros

proc replaceNodes(ast: NimNode, what: NimNode, by: NimNode): NimNode =
  # Replace "what" ident node by "by"
  proc inspect(node: NimNode): NimNode =
    case node.kind:
    of {nnkIdent, nnkSym}:
      if node.eqIdent(what):
        return by
      return node
    of nnkEmpty:
      return node
    of nnkLiterals:
      return node
    else:
      var rTree = node.kind.newTree()
      for child in node:
        rTree.add inspect(child)
      return rTree
  result = inspect(ast)

macro staticFor*(idx: untyped{nkIdent}, slice: static Slice[int], body: untyped): untyped =
  ## Unrolled `for` loop over the given range:
  ##
  ## ```nim
  ## staticFor(i, 0..<2):
  ##   echo default(array[i, byte])
  ## ```
  result = newStmtList()
  for i in slice:
    result.add nnkBlockStmt.newTree(
      ident(":staticFor" & $idx & $i),
      body.replaceNodes(idx, newLit i)
    )
