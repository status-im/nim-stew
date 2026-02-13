# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

## Enable `lent` usage in newer Nim versions where it's known to work well.

# Based on https://github.com/arnetheduck/nim-results/blob/df8113dda4c2d74d460a8fa98252b0b771bf1f27/results.nim#L380
const useLent* =
  (NimMajor, NimMinor, NimPatch) >= (2, 2, 0) or
  (defined(gcRefc) and ((NimMajor, NimMinor, NimPatch) >= (2, 0, 8)))

when useLent:
  template maybeLent*(T: untyped): untyped =
    ## Generate `lent T` in newer Nim versions, generate `T` otherwise.
    lent T
else:
  template maybeLent*(T: untyped): untyped =
    T
