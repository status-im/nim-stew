import
  tables, macros

macro fauxClosureAux(procName: untyped, procDef: typed): untyped =
  type ParamRegistryEntry = object
    origSymbol: NimNode
    newParam: NimNode

  var params = initTable[string, ParamRegistryEntry]()

  proc makeParam(replacedSym: NimNode,
                 registryEntry: var ParamRegistryEntry): NimNode =
    if registryEntry.newParam == nil:
      registryEntry.origSymbol = replacedSym
      registryEntry.newParam = genSym(nskParam, $replacedSym)
    return registryEntry.newParam

  let realClosureSym = procDef.name

  proc registerParamsInBody(n: NimNode) =
    for i in 0 ..< n.len:
      let son = n[i]
      case son.kind
      of nnkIdent, nnkCharLit..nnkTripleStrLit:
        discard
      of nnkSym:
        if son.symKind in {nskLet, nskVar, nskForVar,
                           nskParam, nskTemp, nskResult}:
          if owner(son) != realClosureSym:
            n[i] = makeParam(son, params.mgetOrPut(son.signatureHash,
                                                   default(ParamRegistryEntry)))
      of nnkHiddenDeref:
        registerParamsInBody son
        n[i] = son[0]
      else:
        registerParamsInBody son

  let
    fauxClosureName = genSym(nskProc, $procName)
    fauxClosureBody = copy procDef.body

  registerParamsInBody fauxClosureBody

  var
    procCall = newCall(fauxClosureName)
    fauxClosureParams = @[newEmptyNode()]

  for hash, param in params:
    var paramType = getType(param.origSymbol)
    if param.origSymbol.symKind in {nskVar, nskResult}:
      if paramType.kind != nnkBracketExpr or not eqIdent(paramType[0], "var"):
        paramType = newTree(nnkVarTy, paramType)

    fauxClosureParams.add newIdentDefs(param.newParam, paramType)
    procCall.add param.origSymbol

  result = newStmtList(
    newProc(name = fauxClosureName,
            params = fauxClosureParams,
            body = fauxClosureBody),

    newProc(name = procName,
            procType = nnkTemplateDef,
            body = procCall))

macro fauxClosure*(procDef: untyped): untyped =
  let name = procDef.name
  procDef.name = genSym(nskProc, $name)
  result = newCall(bindSym"fauxClosureAux", name, procDef)

