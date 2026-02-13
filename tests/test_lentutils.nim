# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}
{.used.}

import
  unittest2,
  ../stew/lentutils

iterator lenter[T](x: T): maybeLent T =
  yield x

suite "Lent utils":
  test "iterator yields a lent type if lent is enabled":
    let s = @[1, 2, 3]
    for x in lenter(s):
      when useLent:
        check unsafeAddr(s) == unsafeAddr(x)
      else:
        check unsafeAddr(s) != unsafeAddr(x)

  when (NimMajor, NimMinor, NimPatch) >= (2, 2, 0):
    test "iterator always yields a lent type in newer Nim":
      let s = @[1, 2, 3]
      for x in lenter(s):
        check unsafeAddr(s) == unsafeAddr(x)

  when (NimMajor, NimMinor, NimPatch) < (2, 0, 8):
    test "iterator never yields a lent type in older Nim":
      let s = @[1, 2, 3]
      for x in lenter(s):
        check unsafeAddr(s) != unsafeAddr(x)
