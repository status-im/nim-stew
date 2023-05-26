# stew
# Copyright 2023 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2,
  ../stew/enums

suite "enumStyle":
  test "OrdinalEnum":
    type EnumTest = enum
      x0,
      x1,
      x2
    check EnumTest.enumStyle == EnumStyle.Numeric

  test "HoleyEnum":
    type EnumTest = enum
      y1 = 1,
      y3 = 3,
      y4,
      y6 = 6
    check EnumTest.enumStyle == EnumStyle.Numeric

  test "StringEnum":
    type EnumTest = enum
      z1 = "aaa",
      z2 = "bbb",
      z3 = "ccc"
    check EnumTest.enumStyle == EnumStyle.AssociatedStrings
