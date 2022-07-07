# stew
# Copyright 2018-2019 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# Running some unit tests in a separate file in order to mitigate global
# symbols overflow on Github ci when compiling with nim version <= 1.2
when 3 <= NimVersion.len and NimVersion[0..2] == "1.2":
  import
    all_tests_ex

# End
