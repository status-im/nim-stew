# stew
# Copyright 2018-2019 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# Pointer operations and helpers - generally, dereferencing pointers that have
# been offset is unsafe and many of the operations herein have undefined
# and platform-specific behavior in corner cases.

# Due to poor codegen and subsequent lack of inlining, many of these operations
# are templates even where they could be func.

# ByteAddress in std lib is signed - this leads to issues with overflow checking
# when address is on boundary.
type
  MemAddress* = distinct uint

template toMemAddress*(p: pointer): MemAddress = cast[MemAddress](p)
template toPointer*(p: MemAddress): pointer = cast[pointer](p)
template toPtr*(p: MemAddress, T: type): ptr T = cast[ptr T](p)

template offset*(p: MemAddress, bytes: int): MemAddress =
  ## Offset a memory address by a number of bytes. Behavior is undefined on
  ## overflow.
  # Actual behavior is wrapping, but this may be revised in the future to enable
  # better optimizations
  {.checks: off.}
  mixin offset
  MemAddress(uint(p) + cast[uint](bytes))

template offset*(p: pointer, bytes: int): pointer =
  ## Offset a memory address by a number of bytes. Behavior is undefined on
  ## overflow.
  # Actual behavior is wrapping, but this may be revised in the future to enable
  # better optimizations
  mixin offset
  p.toMemAddress().offset(bytes).toPointer()

template offset*[T](p: ptr T, count: int): ptr T =
  ## Offset a pointer to T by count elements. Behavior is undefined on
  ## overflow.
  # Actual behavior is wrapping, but this may be revised in the future to enable
  # better optimizations.
  # We turn off checking here - too large counts is UB
  {.checks: off.}
  mixin offset
  let bytes = count * sizeof(T)
  p.toMemAddress().offset(bytes).toPtr(type p[])

template distance*(a, b: MemAddress): int =
  cast[int](cast[uint](b) - cast[uint](a))

template distance*(a, b: pointer): int =
  # Number of bytes between a and b - undefined behavior when difference exceeds
  # what can be represented in an int
  a.toMemAddress().distance(b.toMemAddress())

template distance*[T](a, b: ptr T): int =
  # Number of elements between a and b - undefined behavior when difference
  # exceeds what can be represented in an int
  {.checks: off.}
  a.toMemAddress().distance(b.toMemAddress()) div sizeof(T)

proc `<`*(a, b: MemAddress): bool =
  cast[uint](a) < cast[uint](b)
