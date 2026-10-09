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
  template unCheckedInc(x) =
    {.push overflowChecks: off.}
    inc(x)
    {.pop.}

  template findIt*(s, predicate: untyped): int =
    ## Iterates through a container and returns the index of the first item that
    ## fulfills the predicate, or -1
    ##
    ## Unlike the `find`, the predicate needs to be an expression using
    ## the `it` variable for testing, like: `findIt([3, 2, 1], it == 2)`.
    var
      res = -1
      i = 0

    # We must use items here since both `find` and `anyIt` are defined in terms
    # of `items`
    # (and not `pairs`)
    for it {.inject.} in items(s):
      if predicate:
        res = i
        break
      unCheckedInc(i)
    res
