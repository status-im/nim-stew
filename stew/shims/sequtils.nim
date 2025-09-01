# stew
# Copyright 2025 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import std/sequtils
export sequtils

when not declared(sequtils.findIt):
  # https://github.com/nim-lang/Nim/pull/25134
  template findIt*(s: openArray, predicate: untyped): int =
    var res = -1
    for i, it {.inject.} in items(s):
      if predicate:
        res = i
        break
    res
