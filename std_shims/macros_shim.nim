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

iterator recordFields*(typeImpl: NimNode): FieldDescription =
  # TODO: This doesn't support inheritance yet
  let
    objectType = typeImpl[2]
    recList = objectType[2]

  if recList.len > 0:
    var traversalStack = @[(recList, 0)]
    while true:
      assert traversalStack.len > 0

      let (recList, idx) = traversalStack[^1]
      let n = recList[idx]
      inc traversalStack[^1][1]

      if idx == recList.len - 1:
        discard traversalStack.pop

      case n.kind
      of nnkRecWhen:
        for i in countdown(n.len - 1, 0):
          let branch = n[i]
          case branch.kind:
          of nnkElifBranch:
            traversalStack.add (branch[1], 0)
          of nnkElse:
            traversalStack.add (branch[0], 0)
          else:
            assert false

        continue

      of nnkRecCase:
        assert n.len > 0
        for i in countdown(n.len - 1, 1):
          let branch = n[i]
          case branch.kind
          of nnkOfBranch:
            traversalStack.add (branch[^1], 0)
          of nnkElse:
            traversalStack.add (branch[0], 0)
          else:
            assert false

        traversalStack.add (newTree(nnkRecCase, n[0]), 0)
        continue

      of nnkIdentDefs:
        let fieldType = n[^2]
        for i in 0 ..< n.len - 2:
          var field: FieldDescription
          field.name = n[i]

          if field.name.kind == nnkPostfix:
            field.isPublic = true
            field.name = field.name[1]

          if field.name.kind == nnkPragmaExpr:
            field.pragmas = field.name[1]
            field.name = field.name[0]

          yield field

      of nnkNilLit, nnkDiscardStmt, nnkCommentStmt, nnkEmpty:
        discard

      else:
        assert false

      if traversalStack.len == 0: break

