# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

import std/typetraits, ./macros

export typetraits

func supportsSharedMem(typ: NimNode): bool =
  let typeImpl = typ.getTypeImpl
  case typeImpl.kind
  of nnkSym:
    typeImpl.typeKind != ntyString
  of nnkBracketExpr:
    case $typeImpl[0]
    of "seq":
      false
    of "array", "UncheckedArray", "sink":
      typeImpl[^1].supportsSharedMem
    else:
      true
  of nnkRefTy:
    false
  of nnkProcTy, nnkIteratorTy:
    not typeImpl.getType[0].hasClosure
  of nnkDistinctTy:
    typeImpl[0].supportsSharedMem
  of nnkObjectTy, nnkTupleTy, nnkTupleConstr:
    let fields = recordFields(typ)
    for i in 0 ..< fields.len:
      if not fields[i].typ.supportsSharedMem:
        return false
    true
  else:
    true

macro supportsSharedMem*(T: type): untyped =
  ## Returns true if `T` does not contain any
  ## `string`, `seq`, `ref` or closure.
  newLit(supportsSharedMem(getTypeInst(T)[1]))
