# stew
# Copyright 2023 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import std/[macros, options]

type EnumStyle* {.pure.} = enum
  Numeric,
  AssociatedStrings

func setMode(style: var Option[EnumStyle], s: EnumStyle, typ: auto) =
  if style.isNone:
    style = some s
  elif style.get != s:
    error("Mixed enum styles not supported for deserialization: " & $typ)
  else:
    discard

macro enumStyle*(t: typedesc[enum]): untyped =
  let
    typ = t.getTypeInst[1]
    impl = typ.getImpl[2]
  expectKind impl, nnkEnumTy

  var style: Option[EnumStyle]
  for f in impl:
    case f.kind
    of nnkEmpty:
      continue
    of nnkIdent:
      when (NimMajor, NimMinor) < (1, 4):  # `nnkSym` in Nim 1.2
        style.setMode(EnumStyle.Numeric, typ)
      else:
        error("Unexpected enum node for deserialization: " & $f.kind)
    of nnkSym:
      style.setMode(EnumStyle.Numeric, typ)
    of nnkEnumFieldDef:
      case f[1].kind
      of nnkIntLit:
        style.setMode(EnumStyle.Numeric, typ)
      of nnkStrLit:
        style.setMode(EnumStyle.AssociatedStrings, typ)
      else: error("Unexpected enum tuple for deserialization: " & $f[1].kind)
    else: error("Unexpected enum node for deserialization: " & $f.kind)

  if style.isNone:
    error("Cannot determine enum style for deserialization: " & $typ)
  case style.get
  of EnumStyle.Numeric:
    quote do:
      EnumStyle.Numeric
  of EnumStyle.AssociatedStrings:
    quote do:
      EnumStyle.AssociatedStrings
