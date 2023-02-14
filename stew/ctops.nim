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

when sizeof(int) == 8:
  type
    AnyItem* = byte|char|int8|uint16|int16|uint32|int32|uint64|int64|uint|int
elif sizeof(int) == 4:
  type
    AnyItem* = byte|char|int8|uint16|int16|uint32|int32|uint|int

when (NimMajor, NimMinor) < (1, 4):
  {.push raises: [Defect].}
else:
  {.push raises: [].}

proc isEqual*[A: AnyItem, B: AnyItem](c: typedesc[CT], a: openArray[A],
                                      b: openArray[B]): bool =
  ## Perform constant time comparison of two arrays ``a`` and ``b``.
  ##
  ## Please note that it only makes sense to compare arrays of the same length.
  ## If length of arrays is not equal only part of array will be compared.
  ##
  ## Procedure returns ``true`` if arrays of same length are equal or
  ## part of array's content is equal to another array's content if arrays
  ## lengths are different.
  ##
  ## Beware that arrays ``a`` and ``b`` MUST NOT BE empty. Types ``A`` and
  ## ``B`` should be equal in size, e.g. ``(sizeof(A) == sizeof(B))``
  doAssert(len(a) > 0 and len(b) > 0)
  doAssert(sizeof(A) == sizeof(B))
  var count = min(len(a), len(b))
  var res = 0'u
  while count > 0:
    dec(count)
    let av = when A is uint: a[count] else: uint(a[count])
    let bv = when B is uint: b[count] else: uint(b[count])
    res = res or (av xor bv)
  (res == 0'u)
