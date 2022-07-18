# byteutils
# Copyright (c) 2018-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  unittest2,
  ../stew/sequtils2

suite "sequtils2":
  test "write":
    block:
      var a: seq[int]

      a.write([0, 1, 2, 3])

      check:
        a == @[0, 1, 2, 3]

      a.write([])
      a.write([4])

      check:
        a == @[0, 1, 2, 3, 4]
    block:
      var a: seq[byte]

      a.write([byte 0, 1, 2, 3])

      check:
        a == [byte 0, 1, 2, 3]

      a.write([])
      a.write([byte 4])

      check:
        a == [byte 0, 1, 2, 3, 4]
