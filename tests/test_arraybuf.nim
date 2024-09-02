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
