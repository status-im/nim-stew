# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

import ./shims/macros

func containsIdent(n: NimNode, idents: openArray[NimNode]): bool =
  if n.kind == nnkIdent:
    for ident in idents:
      if eqIdent(n, ident):
        return true
  for child in n:
    if child.containsIdent(idents):
      return true
  false

func staticCaseParamType(typ: NimNode, generics: openArray[NimNode]): NimNode =
  if typ.kind == nnkVarTy:
    staticCaseParamType(typ[0], generics)
  elif typ.kind == nnkInfix and eqIdent(typ[0], "|"):
    staticCaseParamType(typ[1], generics)
  elif typ.kind == nnkBracketExpr and typ.containsIdent(generics):
    typ[0]  # Generic params are not in scope, use the uninstantiated type
  else: typ

func staticCaseType(T: NimNode): NimNode =
  let
    typ = T.getTypeInst[1]
    impl = typ.getTypeImpl
  if impl.kind == nnkBracketExpr and eqIdent(impl[0], "or"): impl[1]
  else: typ

func staticCaseDiscriminator(typ: NimNode): FieldDescription =
  if typ.getTypeImpl.kind in {nnkObjectTy, nnkRefTy, nnkPtrTy}:
    let fields = recordFields(typ)
    var res: FieldDescription
    for i in 0 ..< fields.len:
      if fields[i].isDiscriminator and fields[i].caseField == nil:
        if res.name != nil:
          macros.error("at most one top-level `case` is supported", typ)
        res = fields[i]
    if res.name != nil:
      return res
  macros.error("enum or case object expected", typ)

func staticCaseBranchFields(typ: NimNode): seq[FieldDescription] =
  if typ.getTypeImpl.kind == nnkEnumTy:
    return @[]
  let
    discriminator = typ.staticCaseDiscriminator
    fields = recordFields(typ)
  var res: seq[FieldDescription]
  for i in 0 ..< fields.len:
    if not fields[i].isDiscriminator and
        fields[i].caseFieldName == discriminator.name:
      res.add fields[i]
  res

func staticCaseField(
    fields: seq[FieldDescription], ordinal: int64, typ: NimNode): NimNode =
  var res: NimNode
  for i in 0 ..< fields.len:
    if fields[i].caseBranchValues.containsOrdinal(ordinal):
      if res != nil:
        macros.error("at most one field per branch is supported", typ)
      res = fields[i].name
  res

macro staticCaseImpl(
    def, name, accessors: untyped, types: varargs[typed]): untyped =
  var params: seq[NimNode]
  for param in def.routineParams:
    params.add param.name
  var
    selector = params[0]
    selectorType = staticCaseType(types[0])
  if selectorType.getTypeImpl.kind != nnkEnumTy:
    let discriminator = selectorType.staticCaseDiscriminator
    selector = newDotExpr(selector, ident $discriminator.name)
    selectorType = discriminator.typ
  var fields: seq[seq[FieldDescription]]
  for i in 0 ..< accessors.len:
    fields.add staticCaseBranchFields(staticCaseType(types[i]))
  let
    caseStmt = nnkCaseStmt.newTree(selector)
    values = enumFields(selectorType)
  for i in 0 ..< values.len:
    let
      value = values[i].name
      branch = newStmtList(quote do:
        const `name` {.inject, used.} = `value`)
    for j, accessor in accessors:
      let field = fields[j].staticCaseField(values[i].ordinal, types[j])
      if field != nil:
        let
          param = params[j]
          fieldName = ident $field
        branch.add quote do:
          template `accessor`: untyped {.inject, used.} = `param`.`fieldName`
    branch.add def.body.copyNimTree
    caseStmt.add nnkOfBranch.newTree(value, branch)
  let res = def.copyNimTree
  res.body = newStmtList(caseStmt)
  res

macro staticCase*(args: varargs[untyped]): untyped =
  ## Template pragma `{.staticCase(name, accessors...).}`.
  ##
  ## For each accessor, the template must have a matching parameter accepting
  ## an enum or a case object with a single top-level `case` section over an
  ## enum with at most one field per branch. Extra template arguments beyond
  ## the required parameters are allowed and left as is.
  ##
  ## The template's body is expanded over the enum value or the discriminator
  ## in a `case` where each branch declares `const name = <value>`, and, for
  ## each accessor, a `template accessor` returning the inner field that the
  ## corresponding parameter holds for the value (if it has one).
  ##
  ## The first parameter decides the `case`, other parameters are assumed to
  ## share the discriminator type and be in the same branch as the first one.
  ## For type class parameters, the first class member defines the fields.
  ## Template parameters may be evaluated multiple times.
  ##
  ## .. code-block:: nim
  ##   template withKind(
  ##       x: Kind, body: untyped
  ##   ): untyped {.staticCase(staticKind).} =
  ##     body
  ##
  ##   template withValue(
  ##       x: Variant, body: untyped
  ##   ): untyped {.staticCase(staticKind, innerField).} =
  ##     body
  ##
  ##   template withValues(
  ##       x: Variant1, y: Variant2, body: untyped
  ##   ): untyped {.staticCase(staticKind, innerField1, innerField2).} =
  ##     body
  if args.len < 2:
    macros.error("`staticCase` expects a name for the case value", args[^1])
  let
    def = args[^1]
    accessors = newTree(nnkBracket, args[1 .. ^2])
  var generics: seq[NimNode]
  if def[2].kind == nnkGenericParams:
    for identDefs in def[2]:
      for generic in identDefs[0 .. ^3]:
        generics.add generic
  var types: seq[NimNode]
  for param in def.routineParams:
    types.add param.typ.staticCaseParamType(generics)
  if types.len < max(accessors.len, 1):
    macros.error("more accessors than parameters", def)
  let res = newCall(bindSym"staticCaseImpl", def, args[0], accessors)
  for i in 0 ..< max(accessors.len, 1):
    res.add types[i]
  res
