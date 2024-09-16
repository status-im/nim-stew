# stew
# Copyright 2024 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.used.}

import
  ../stew/arraybuf,
  unittest2

suite "ArrayBuf":
  test "single evaluation":
    var v: byte = 0
    proc f(): ArrayBuf[33, byte] =
      v += 1
      result.add v

    # check doesn't support `openArray` (!)
    doAssert f().data() == [byte 1]

  test "overflow add":
    var v: ArrayBuf[2, byte]
    v.add(byte 0)
    doAssert v.data() == [byte 0]

    v.add([byte 1, 2, 3])

    doAssert v.data() == [byte 0, 1]

    v.add(byte 4)
    doAssert v.data() == [byte 0, 1]

  test "setLen clearing":
    var v: ArrayBuf[5, byte]

    v.add(1)
    v.add(2)

    check: v.pop() == 2

    v.setLen(2)
    check:
      v[^1] == 0 # not 2!


    v[1] = 42

    v.setLen(1)
    check:
      v[0] == 1
      v.len == 1
    v.setLen(2)
    doAssert v.data() == [byte 0, 1]
