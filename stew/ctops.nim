## Copyright (c) 2020 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements different operations which will execute in amount of
## time (or memory space) independent of the input size.

type
  CT* = object
  AnyByte* = byte | char

proc isEqual*[A: AnyByte, B: AnyByte](c: typedesc[CT], a: openArray[A],
                                      b: openArray[B]): bool {.
     raises: [Defect] .} =
  ## Perform constant time comparison of two arrays ``a`` and ``b``.
  ##
  ## Please note that it only makes sense to compare arrays of the same length.
  ## If length of arrays is not equal only part of array will be compared.
  ##
  ## Procedure returns ``true`` if arrays of same length are equal or
  ## part of array's content is equal to another array's content if arrays
  ## lengths are different.
  ##
  ## Beware that arrays ``a`` and ``b`` MUST NOT BE empty.
  doAssert(len(a) > 0 and len(b) > 0)
  var count = min(len(a), len(b))
  var res = 0
  while count > 0:
    dec(count)
    res = res or int(int(a[count]) xor int(b[count]))
  (res == 0)
