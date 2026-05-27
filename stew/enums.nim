# stew
# Copyright 2023-2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

import std/[macros, options, sequtils, typetraits]

type EnumStyle* {.pure.} = enum
  Numeric
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

macro enumRangeInt64*(a: type[enum]): untyped =
  ## This macro returns an array with all the ordinal values of an enum
  let
    values = a.getType[1][1..^1]
    valuesOrded = values.mapIt(newCall("int64", it))
  newNimNode(nnkBracket).add(valuesOrded)

macro enumStrValuesArrayImpl(a: type[enum]): untyped =
  ## This macro returns an array with all the ordinal values of an enum
  let
    values = a.getType[1][1..^1]
    valuesOrded = values.mapIt(newCall("$", it))
  newNimNode(nnkBracket).add(valuesOrded)

# TODO: This should be a proc returning a lent view over the
#       const value. This will ensure only a single instace
#       of the array is generated.
template enumStrValuesArray*(E: type[enum]): auto =
  const values = enumStrValuesArrayImpl E
  values

# TODO: This should be a proc returning a lent view over the
#       const value. This will ensure only a single instace
#       of the sequence is generated.
template enumStrValuesSeq*(E: type[enum]): seq[string] =
  const values = @(enumStrValuesArray E)
  values

template hasHoles*(T: type enum): bool =
  T is typetraits.HoleyEnum

func contains*[I: SomeInteger](e: type[enum], v: I): bool =
  when I is uint64:
    if v > int64.high.uint64:
      return false
  when e.hasHoles():
    v.int64 in enumRangeInt64(e)
  else:
    v.int64 in e.low.int64 .. e.high.int64

func checkedEnumAssign*[E: enum, I: SomeInteger](res: var E, value: I): bool =
  ## This function can be used to safely assign a tainted integer value (coming
  ## from untrusted source) to an enum variable. The function will return `true`
  ## if the integer value is within the acceped values of the enum and `false`
  ## otherwise.

  if value notin E:
    false
  else:
    res = cast[E](value)
    true
