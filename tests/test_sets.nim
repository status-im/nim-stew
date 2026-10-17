# Copyright (c) 2021-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2,
  ../stew/shims/sets

suite "shims/sets":
  test "keepItIf":
    var s1 = init HashSet[int]
    s1.incl 10
    s1.incl 20
    s1.incl 30

    s1.keepItIf(it > 15)

    check:
      s1.len == 2
      10 notin s1
      20 in s1
      30 in s1

    var s2 = init HashSet[string]
    s2.keepItIf(it.len > 0)

    check s2.len == 0

    s2.incl "test"
    s2.keepItIf(it.len > 10)
    check s2.len == 0

    s2.incl "test"
    s2.keepItIf(it.len > 0)
    check:
      s2.len == 1
      "test" in s2
