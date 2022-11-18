# stew
# Copyright 2018-2022 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# Pointer operations and helpers - generally, dereferencing pointers that have
# been offset is unsafe and many of the operations herein have undefined
# and platform-specific behavior in corner cases.

# Due to poor codegen and subsequent lack of inlining, these operations
# are templates even where they could be func.

# Note that `ByteAddress` in stdlib is implemented as a signed integer and
# might lead to overflow on arithmetic - avoid

{.push raises: [].}

template offset*(p: pointer, bytes: int): pointer =
  ## Offset a memory address by a number of bytes. Behavior is undefined on
  ## overflow.
  # Actual behavior is wrapping, but this may be revised in the future to enable
  # better optimizations

  # We assume two's complement wrapping behaviour for `uint`
  cast[pointer](cast[uint](p) + cast[uint](bytes))

template offset*[T](p: ptr T, count: int): ptr T =
  ## Offset a pointer to T by count elements. Behavior is undefined on
  ## overflow.

  # Actual behavior is wrapping, but this may be revised in the future to enable
  # better optimizations.
  let bytes = cast[uint](count) * uint(sizeof(T))
  cast[ptr T](offset(cast[pointer](p), cast[int](bytes)))

template distance*(a, b: pointer): int =
  ## Number of bytes between a and b - undefined behavior when difference
  ## exceeds what can be represented in an int

  # We assume two's complement wrapping behaviour for `uint`
  cast[int](cast[uint](b) - cast[uint](a))

template distance*[T](a, b: ptr T): int =
  # Number of elements between a and b - undefined behavior when difference
  # exceeds what can be represented in an int
  distance(cast[pointer](a), cast[pointer](b)) div sizeof(T)

proc baseAddr*[T](x: openArray[T]): ptr T =
  # Return the address of the zero:th element of x or `nil` if x is empty
  if x.len == 0: nil else: cast[ptr T](x)

template makeOpenArray*[T](p: ptr T, len: Natural): openArray[T] =
  toOpenArray(cast[ptr UncheckedArray[T]](p), 0, len - 1)

template makeOpenArray*(p: pointer, T: type, len: Natural): openArray[T] =
  toOpenArray(cast[ptr UncheckedArray[T]](p), 0, len - 1)
