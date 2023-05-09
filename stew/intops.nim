## Core integer primitives suitable as building blocks for higher-level
## functionality such as bigints, saturating integer types etc - where
## applicable, these use compiler builtins - otherwise, they fall back on native
## Nim code that may be less efficient.
##
## In using these functions, it is recommended that you always call the function
## that returns the least information needed - for example, `mulOverflow` may
## be implemented more efficiently than `mulWiden`, meaning that if overflow
## detection is all that is needed, use the former.

# Implementation notes:
#
# * `uintN` is assumed to be wrapping
# * "*Overflow" perform wrapping arithmetic while returning a bool for overflow
# * "*Widen" return full result in multiple words
# * overloads with carry/borrow exposed for chaining limbs
#
# TODO
# * use compiler intrinsics
# * signed ops
# * saturating ops
# * more primitives commonly available on CPU:s / intrinsics (pow / divmod / etc)
#
# References:
# https://llvm.org/docs/LangRef.html#arithmetic-with-overflow-intrinsics
# https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html
# https://doc.rust-lang.org/std/primitive.u32.html#implementations

func addOverflow*(x, y: SomeUnsignedInt):
    tuple[result: SomeUnsignedInt, overflow: bool] =
  ## Add the two integers using wrapping arithmetic, returning the result and a
  ## boolean indicating that overflow happened.
  ##
  ## When used to construct bigint arithmetic, the overflow flag can be passed
  ## as carry to the next more significant word.

  let r = x + y
  (r, r < x)

func addOverflow*(x, y: SomeUnsignedInt, carry: bool):
    tuple[result: SomeUnsignedInt, overflow: bool] =
  ## Add two integers and carry using wrapping arithmetic, returning the
  ## result and a boolean indicating that overflow happened.
  ##
  ## When used to construct bigint arithmetic, the overflow flag can be passed
  ## as carry to the next more significant word.

  let
    (a, b) = addOverflow(x, y)
    (c, d) = addOverflow(a, typeof(a)(carry))
  (c, b or d)

func subOverflow*(x, y: SomeUnsignedInt):
    tuple[result: SomeUnsignedInt, overflow: bool] =
  ## Subtract y and borrow from x using wrapping arithmetic, returning the
  ## result and a boolean indicating whether overflow happened.

  let r = x - y
  (r, y > x)

func subOverflow*(x, y: SomeUnsignedInt, borrow: bool):
    tuple[result: SomeUnsignedInt, overflow: bool] =
  ## Subtract y and borrow from x using wrapping arithmetic, returning the
  ## result and a boolean indicating whether overflow happened.
  ##
  ## When used to construct bigint arithmetic, the overflow flag can be passed
  ## as carry to the next more significant word.

  let
    (a, b) = subOverflow(x, y)
    (c, d) = subOverflow(a, typeof(a)(borrow))
  (c, b or d)

func mulWiden*(x, y: uint64): tuple[lo, hi: uint64] =
  let
    x0 = x and uint32.high
    x1 = x shr 32
    y0 = y and uint32.high
    y1 = y shr 32
    p11 = x1 * y1
    p01 = x0 * y1
    p10 = x1 * y0
    p00 = x0 * y0
    middle = p10 + (p00 shr 32) + (p01 and uint32.high)
    rhi = p11 + (middle shr 32) + (p01 shr 32)
    rlo = (middle shl 32) or (p00 and uint32.high)

  (rlo, rhi)

func mulWiden*(x, y: uint32): tuple[lo, hi: uint32] =
  let r = x.uint64 * y.uint64
  (cast[uint32](r and uint32.high), cast[uint32](r shr 32))
func mulWiden*(x, y: uint16): tuple[lo, hi: uint16] =
  let r = x.uint32 * y.uint32
  (cast[uint16](r and uint16.high), cast[uint16](r shr 16))
func mulWiden*(x, y: uint8): tuple[lo, hi: uint8] =
  let r = x.uint16 * y.uint16
  (cast[uint8](r and uint8.high), cast[uint8](r shr 8))
func mulWiden*(x, y: uint): tuple[lo, hi: uint] =
  ## Perform `(x * y)` as if the computiation had been carried out in twice as
  ## wide a type returning the low and high words.
  when sizeof(uint) == sizeof(uint64):
    let (a, b) = mulWiden(uint64(x), uint64(y))
  else:
    let (a, b) = mulWiden(uint32(x), uint64(y))
  (uint(a), uint(b))

func mulWiden*(x, y, carry: SomeUnsignedInt): tuple[lo, hi: SomeUnsignedInt] =
  ## Perform `((x * y) + carry)` as if the computiation had been carried out in
  ## twice as wide a type returning the low and high words
  let
    (lo, hi) = mulWiden(x, y)
    (a, b) = addOverflow(lo, carry)
    # The carry from this overflowing add can be ignored since the result of
    # a multiplication always leaves room for adding one more `high`
    (c, _) = addOverflow(hi, typeof(hi)(0), b)

  (a, c)

func mulOverflow*(x, y: SomeUnsignedInt):
    tuple[result: SomeUnsignedInt, overflow: bool] =
  ## Perform `(x * y)` using wrapping arithmetic, returning the result and a
  ## boolean indicating that overflow happened.
  let
    (a, b) = mulWiden(x, y)
  (a, b > 0)
