# Copyright (c) 2021-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2,
  ../stew/templateutils

var computations = newSeq[string]()
var templateParamAddresses = newSeq[pointer]()

type
  ObjectHoldingSeq = object
    data: seq[int]

proc accessSeq(x: var ObjectHoldingSeq): var seq[int] =
  computations.add("accessor")
  x.data

proc expensiveComputation(evaluationLabel: string): seq[int] =
  computations.add evaluationLabel
  return @[1, 2, 3]

template reject(code: untyped) =
  static: assert(not compiles(code))

template evalManyTimes(xParam: untyped, shouldBeMutable: bool): string =
  var res: string
  evalTemplateParamOnce(xParam, x):
    res = $x

    when shouldBeMutable:
      x.add 10
    else:
      reject:
        x.add(10)

    res.add " => "
    res.add $x

    templateParamAddresses.add(unsafeAddr x)
  res

test "Template utils":
  # Pass function call
  check "@[1, 2, 3] => @[1, 2, 3]" == evalManyTimes(
    expensiveComputation("call"), shouldBeMutable = false)

  # Pass var symbol
  var s1 = expensiveComputation("var")
  check "@[1, 2, 3] => @[1, 2, 3, 10]" == evalManyTimes(
    s1, shouldBeMutable = true)

  # Pass let symbol:
  let s2 = expensiveComputation("let")
  check "@[1, 2, 3] => @[1, 2, 3]" == evalManyTimes(
    s2, shouldBeMutable = false)

  var o = ObjectHoldingSeq(data: @[1, 2, 3])
  check "@[1, 2, 3] => @[1, 2, 3, 10]" == evalManyTimes(
    o.accessSeq, shouldBeMutable = true)

  check computations == ["call", "var", "let", "accessor"]

  check:
    templateParamAddresses[1] == addr s1
    templateParamAddresses[2] == unsafeAddr s2
    templateParamAddresses[3] == addr o.accessSeq
