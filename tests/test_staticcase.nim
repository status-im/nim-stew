# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import unittest2, ../stew/staticcase

type
  StaticCaseKind = enum
    staticA, staticB, staticC

  StaticCaseObject = object
    case kind: StaticCaseKind
    of staticA:
      aField: int
    of staticB:
      bField: string
    of staticC:
      discard

  SameLayoutStaticCaseObject = object
    case kind: StaticCaseKind
    of staticA:
      aField: int
    of staticB:
      bField: string
    of staticC:
      discard

  SomeStaticCaseObject = StaticCaseObject | SameLayoutStaticCaseObject

  OtherStaticCaseObject = object
    case kind: StaticCaseKind
    of staticA:
      otherA: float
    of staticB, staticC:
      otherBC: int

  RangeStaticCaseObject = object
    case kind: StaticCaseKind
    of staticA:
      rangeA: int
    of staticB .. staticC:
      rangeBC: string

  ElseStaticCaseObject = object
    case kind: StaticCaseKind
    of staticA:
      elseA: int
    else:
      elseBC: string

  QuotedStaticCaseObject = object
    case `quoted kind`: StaticCaseKind
    of staticA:
      quotedA: int
    of staticB, staticC:
      quotedBC: string

  TwoFieldsStaticCaseObject = object
    case kind: StaticCaseKind
    of staticA:
      firstA, secondA: int
    of staticB, staticC:
      discard

  RefStaticCaseObject = ref object
    case kind: StaticCaseKind
    of staticA:
      refA: int
    of staticB, staticC:
      discard

  GenericStaticCaseObject[T] = object
    case kind: StaticCaseKind
    of staticA:
      genericA: T
    of staticB, staticC:
      discard

const staticBC = {staticB, staticC}

type SetStaticCaseObject = object
  case kind: StaticCaseKind
  of staticA:
    setA: int
  of staticBC:
    setBC: string

template withStaticCaseKind(
    x: StaticCaseKind, body: untyped
): untyped {.staticCase(staticKind).} =
  body

template withStaticCaseObject(
    x: StaticCaseObject | SameLayoutStaticCaseObject, body: untyped
): untyped {.staticCase(staticKind, innerField).} =
  body

template withSomeStaticCaseObject(
    x: SomeStaticCaseObject, body: untyped
): untyped {.staticCase(staticKind, innerField).} =
  body

template withStaticCaseObjects(
    x: StaticCaseObject, y: OtherStaticCaseObject, body: untyped
): untyped {.staticCase(staticKind, innerField, otherInnerField).} =
  template kindName: untyped {.inject, used.} = $staticKind
  body

template withRangeStaticCaseObject(
    x: RangeStaticCaseObject, body: untyped
): untyped {.staticCase(staticKind, innerField).} =
  body

template withSetStaticCaseObject(
    x: SetStaticCaseObject, body: untyped
): untyped {.staticCase(staticKind, innerField).} =
  body

template withElseStaticCaseObject(
    x: ElseStaticCaseObject, body: untyped
): untyped {.staticCase(staticKind, innerField).} =
  body

template withQuotedStaticCaseObject(
    x: QuotedStaticCaseObject, body: untyped
): untyped {.staticCase(staticKind, innerField).} =
  body

template withVarStaticCaseObject(
    x: var StaticCaseObject, body: untyped
): untyped {.staticCase(staticKind, innerField).} =
  body

template withRefStaticCaseObject(
    x: RefStaticCaseObject, body: untyped
): untyped {.staticCase(staticKind, innerField).} =
  body

template withGenericStaticCaseObject[T](
    x: GenericStaticCaseObject[T], body: untyped
): untyped {.staticCase(staticKind, innerField).} =
  body

func staticCaseFields(x: SomeStaticCaseObject): string =
  withStaticCaseObject(x):
    when staticKind == staticA:
      $staticKind & " " & $innerField
    elif staticKind == staticB:
      $staticKind & " " & innerField
    else:
      $staticKind & " " & $declared(innerField)

suite "staticcase":
  test "Enum only":
    check withStaticCaseKind(staticB, $staticKind) == "staticB"

  test "Single parameter":
    check:
      staticCaseFields(
        StaticCaseObject(kind: staticA, aField: 1)) == "staticA 1"
      staticCaseFields(
        SameLayoutStaticCaseObject(kind: staticB, bField: "b")) == "staticB b"
      staticCaseFields(
        StaticCaseObject(kind: staticC)) == "staticC false"

    let someValue = withSomeStaticCaseObject(
        SameLayoutStaticCaseObject(kind: staticA, aField: 2)):
      when staticKind == staticA: innerField else: 0
    check someValue == 2

  test "Multiple parameters":
    var values: seq[string]
    let
      xs = [
        StaticCaseObject(kind: staticA, aField: 1),
        StaticCaseObject(kind: staticB, bField: "b"),
        StaticCaseObject(kind: staticC)]
      ys = [
        OtherStaticCaseObject(kind: staticA, otherA: 1.5),
        OtherStaticCaseObject(kind: staticB, otherBC: 2),
        OtherStaticCaseObject(kind: staticC, otherBC: 3)]
    for i in 0 ..< xs.len:
      withStaticCaseObjects(xs[i], ys[i]):
        when staticKind == staticC:
          values.add kindName & " " & $otherInnerField
        else:
          values.add kindName & " " & $innerField & " " & $otherInnerField
    check values == @["staticA 1 1.5", "staticB b 2", "staticC 3"]

    var rangeValues: seq[string]
    for x in [
        RangeStaticCaseObject(kind: staticA, rangeA: 1),
        RangeStaticCaseObject(kind: staticB, rangeBC: "b"),
        RangeStaticCaseObject(kind: staticC, rangeBC: "c")]:
      withRangeStaticCaseObject(x):
        rangeValues.add $staticKind & " " & $innerField
    check rangeValues == @["staticA 1", "staticB b", "staticC c"]

    var setValues: seq[string]
    for x in [
        SetStaticCaseObject(kind: staticA, setA: 2),
        SetStaticCaseObject(kind: staticB, setBC: "bb"),
        SetStaticCaseObject(kind: staticC, setBC: "cc")]:
      withSetStaticCaseObject(x):
        setValues.add $staticKind & " " & $innerField
    check setValues == @["staticA 2", "staticB bb", "staticC cc"]

    var elseValues: seq[string]
    for x in [
        ElseStaticCaseObject(kind: staticA, elseA: 3),
        ElseStaticCaseObject(kind: staticB, elseBC: "bbb"),
        ElseStaticCaseObject(kind: staticC, elseBC: "ccc")]:
      withElseStaticCaseObject(x):
        elseValues.add $staticKind & " " & $innerField
    check elseValues == @["staticA 3", "staticB bbb", "staticC ccc"]

    var quotedValues: seq[string]
    for x in [
        QuotedStaticCaseObject(`quoted kind`: staticA, quotedA: 4),
        QuotedStaticCaseObject(`quoted kind`: staticB, quotedBC: "bbbb"),
        QuotedStaticCaseObject(`quoted kind`: staticC, quotedBC: "cccc")]:
      withQuotedStaticCaseObject(x):
        quotedValues.add $staticKind & " " & $innerField
    check quotedValues == @["staticA 4", "staticB bbbb", "staticC cccc"]

    when compiles(block:
        template withTwoFields(
            x: TwoFieldsStaticCaseObject, body: untyped
        ): untyped {.staticCase(staticKind, innerField).} =
          body):
      check false

  test "Parameter wrappers":
    var x = StaticCaseObject(kind: staticA, aField: 1)
    withVarStaticCaseObject(x):
      when staticKind == staticA:
        innerField = 2
    check x.aField == 2

    let r = RefStaticCaseObject(kind: staticA, refA: 3)
    withRefStaticCaseObject(r):
      when staticKind == staticA:
        innerField = 4
    check r.refA == 4

    let genericValue = withGenericStaticCaseObject(
        GenericStaticCaseObject[string](kind: staticA, genericA: "g")):
      when staticKind == staticA: innerField else: ""
    check genericValue == "g"
