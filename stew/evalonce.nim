# stew
# Copyright 2024 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import std/macros

macro evalOnceAs*(exp, alias: untyped): untyped =
  ## Ensure that `exp` is evaluated only once unless it is a symbol in which
  ## case it's used directly.
  ##
  ## A common case where this is useful is template parameters which, when
  ## an expression is passed in, get evaluated multiple times.
  ##
  ## Based on a similar macro in std/sequtils
  expectKind(alias, nnkIdent)

  let
    body = nnkStmtList.newTree()
    val =
      if exp.kind == nnkSym:
        # The symbol can be used directly
        # TODO dot expressions? etc..
        exp
      else:
        let val = genSym(ident = "evalOnce_" & $alias)
        body.add newLetStmt(val, exp)
        val
  body.add(
    newProc(
      name = genSym(nskTemplate, $alias),
      params = [getType(untyped)],
      body = val,
      procType = nnkTemplateDef,
    )
  )

  body
