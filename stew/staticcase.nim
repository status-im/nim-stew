# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

import std/macrocache, ./shims/macros

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

func staticCaseInfo(T: NimNode): NimNode =
  ## `(discriminator, [(value, field)...])`, with empty nodes where absent.
  var typ = T.getTypeInst[1]
  if typ.isSink:
    typ = typ[1]
  let cache = CacheSeq("stew.staticcase.staticCaseInfo." & typ.repr)
  for entry in cache:
    if sameType(entry[0], typ):
      return entry[1]
  var
    discriminator = newEmptyNode()
    selectorType = typ
  if typ.getTypeImpl.kind != nnkEnumTy:
    let field = typ.staticCaseDiscriminator
    discriminator = ident $field.name
    selectorType = field.typ
  let
    fields = typ.staticCaseBranchFields
    values = enumFields(selectorType)
    branches = newNimNode(nnkBracket)
  for i in 0 ..< values.len:
    let field = fields.staticCaseField(values[i].ordinal, typ)
    branches.add nnkPar.newTree(
      values[i].name, if field != nil: ident $field else: newEmptyNode())
  let res = nnkPar.newTree(discriminator, branches)
  cache.add nnkPar.newTree(typ, res)
  res

macro staticCaseImpl(
    name, accessors, params, body: untyped, types: varargs[typed]): untyped =
  var infos: seq[NimNode]
  for i in 0 ..< types.len:
    infos.add staticCaseInfo(types[i])
  var selector = params[0]
  if infos[0][0].kind != nnkEmpty:
    selector = newDotExpr(selector, infos[0][0])
  let caseStmt = nnkCaseStmt.newTree(selector)
  for branchInfo in infos[0][1]:
    let
      value = branchInfo[0]
      branch = newStmtList(quote do:
        const `name` {.inject, used.} = `value`)
    for j, accessor in accessors:
      for otherInfo in infos[j][1]:
        let fieldName = otherInfo[1]
        if otherInfo[0].intVal == value.intVal and fieldName.kind != nnkEmpty:
          let param = params[j]
          branch.add quote do:
            template `accessor`: untyped {.inject, used.} = `param`.`fieldName`
    branch.add body.copyNimTree
    caseStmt.add nnkOfBranch.newTree(value, branch)
  caseStmt

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
  var params: seq[NimNode]
  for param in def.routineParams:
    params.add param.name
  let numTypes = max(accessors.len, 1)
  if params.len < numTypes:
    macros.error("more accessors than parameters", def)
  let call = newCall(
    bindSym"staticCaseImpl", args[0], accessors,
    newTree(nnkBracket, params[0 ..< numTypes]), def.body)
  for i in 0 ..< numTypes:
    call.add newCall(ident"typeof", params[i])
  let res = def.copyNimTree
  res.body = newStmtList(call)
  res
