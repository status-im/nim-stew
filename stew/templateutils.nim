# stew
# Copyright 2026 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import ./lentutils

iterator evalTemplateParamOnceImpl[T](x: T): maybeLent T =
  yield x

iterator evalTemplateParamOnceImpl[T](x: var T): var T =
  yield x

template evalTemplateParamOnce*(templateParam, newName, blk: untyped) =
  ## This can be used in templates to avoid the problem of multiple
  ## evaluation of template parameters. Compared to the naive approach
  ## of introducing an additional local variable, it has two benefits:
  ##
  ## * It avoids copying whenever possible.
  ## * It works for var parameters.
  ##
  ## Usage example:
  ##
  ## template foo(xParam: SomeType) =
  ##   evalTemplateParamOnce(xParam, x):
  ##     echo x
  ##     echo x
  ##
  ##  A currently existing limitation is that the `evalTemplateParamOnce`
  ##  block is considered a `void` expression, so templates returning
  ##  expressions may find it difficult to benefit fully from the construct.
  ##
  ##  Please also note that using conrol-flow statements such as `return`,
  ##  `continue` and `break` within the template code is possible, but
  ##  extra care must be taken to ensure that they are not referring to the
  ##  inserted `for` loop (you may need to introduce enclosing named blocks
  ##  for correct implementation of both `break` and `continue`).
  ##
  ##  Both limitations will be lifted in a future implementation based on
  ##  view types.
  block:
    for newName in evalTemplateParamOnceImpl(templateParam):
      blk
