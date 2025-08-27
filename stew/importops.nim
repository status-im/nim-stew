# Copyright (c) 2025 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

template tryImport*(v: untyped): bool =
  ## Try to import `v` and return true if it succeeded - use like so:
  ##
  ## ```nim
  ## when tryImport json_serialization:
  ##   ...
  ##
  ## when tryImport json_serialization as js:
  ##   ...
  ## ```
  # TODO https://github.com/nim-lang/Nim/issues/25108
  when compiles((; import v)):
    import v
    true
  else:
    false
