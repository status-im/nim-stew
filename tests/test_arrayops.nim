# stew
# Copyright 2018-2019 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  std/unittest,
  ../stew/arrayops

suite "arrayops":
  test "basic":
    let
      a = [byte 0, 1]
      b = [byte 4, 5]

    check:
      (a and b) == [a[0] and b[0], a[1] and b[1]]
      (a or b) == [a[0] or b[0], a[1] or b[1]]
      (a xor b) == [a[0] xor b[0], a[1] xor b[1]]
      (not a) == [not a[0], not a[1]]
