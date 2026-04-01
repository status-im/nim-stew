## Low-level little-endian base 128 variable length integer/byte converters, as
## described in https://en.wikipedia.org/wiki/LEB128 - up to 64 bits supported.
##
## The leb128 encoding is used in DWARF and WASM.
##
## It is also fully compatible with the unsigned varint encoding found in
## `protobuf` and `go`, and can thus be used directly. It's easy to build
## support for the two kinds (zig-zag and cast) of signed encodings on top.
##
## This is not the only way to encode variable length integers - variations
## exist like sqlite and utf-8 - in particular, the `std/varints` module
## implements the sqlite flavour.
##
## This implementation contains low-level primitives suitable for building
## more easy-to-use API.
##
## Exception/Defect free as of nim 1.2.
##
## Security notes:
##
## leb128 allows overlong byte sequences that decode into the same integer -
## the library decodes these sequences to a certain extent, but will stop
## decoding at the maximum length that a minimal encoder will produce. For
## example, the byte sequence `[byte 0x80, 0x80, 0x00]`, when decoded as a
## `uint64` is a valid encoding for `0` because the maximum length of a minimal
## `uint64` encoding is 10 bytes - however, because all minimal encodings
## for `uint8` fit in 2 bytes, decoding the same byte sequence as `uint8` will
## yield an error return.
##
## To be strict about overlong encodings, compare the decoded number of bytes
## with `Leb128.len(decoded_value)`.

{.push raises: [].}

import
  stew/bitops2

const
  # Given the truncated logarithm of a 64-bit number, how many bytes do we need
  # to encode it?
  lengths = block:
    var v: array[64, int8]
    for i in 0..<64:
      v[i] = int8((i + 7) div 7)
    v

type
  Leb128* = object
    ## Type used to mark leb128 encoding helpers

# log2trunc by definition never returns values >64, thus we can remove checks
{.push checks: off.}
func len*(T: type Leb128, x: SomeUnsignedInt): int8 =
  ## Returns number of bytes required to encode integer ``x`` as leb128.
  if x == 0: 1 # Always at least one byte!
  else: lengths[log2trunc(x)]
{.pop.}

func maxLen*(T: type Leb128, I: type): int8 =
  ## The maximum number of bytes needed to encode any value of type I
  Leb128.len(I.high)

type
  Leb128Buf*[T: SomeUnsignedInt] = object
    data*: array[maxLen(Leb128, T), byte] # len(data) <= 10
    len*: int8 # >= 1 when holding valid leb128

template write7(next: untyped) =
  # write 7 bits of data
  if v > type(v)(127):
    result.data[result.len] = cast[byte](v and type(v)(0xff)) or 0x80'u8
    result.len += 1
    v = v shr 7
    next

# LebBuf size corresponds to maximum size that the type will be encoded to, thus
# there can be no out-of-bounds accesses here - likewise with the length
# arithmetic
{.push checks: off.}
func toBytes*[I: SomeUnsignedInt](v: I, T: type Leb128): Leb128Buf[I] {.noinit.} =
  ## Convert an unsigned integer to the smallest leb128 representation possible
  ##
  ## Example:
  ## 15'u16.toBytes(Leb128)
  var
    v = v
  result.len = 0

  # A clever developer would write something clever for the unrolling -
  # fortunately, we have clever compilers that remove the excess unrolls based
  # on size!
  write7(): # 7
    write7(): # 14
      write7(): # 21
        write7(): # 28
          write7(): # 35
            write7(): # 42
              write7(): # 49
                write7(): # 56
                  write7(): # 63
                    discard

  # high bit not set since v <= 127 at this point!
  result.data[result.len] = cast[byte](v and type(v)(0xff))
  result.len += 1

template read7(shift: untyped) =
  # Read 7 bits of data and return iff these are the last 7 bits
  if (shift div 7) >= xlen:
    return (I(0), 0'i8) # Not enough data - return 0 bytes read

  when shift >= sizeof(I) * 8:
    # avoid shift overflows: https://github.com/nim-lang/Nim/issues/19983
    if true:
      return (I(0), -cast[int8]((shift div 7) + 1))

  let
    b = x[shift div 7]
    valb = b and 0x7f'u8 # byte without high bit
    val = I(valb)
    vals = val shl shift

  when shift > (sizeof(val) * 8 - 7):
    # Check for overflow in the "unused" bits of the byte we just read
    if vals shr shift != val:
      return (I(0), -cast[int8]((shift div 7) + 1))

  res = res or vals
  if b == valb: # High bit not set, we're done
    return (res, cast[int8]((shift div 7) + 1))

func fromBytes*(
    I: type SomeUnsignedInt,
    x: openArray[byte],
    T: type Leb128): tuple[val: I, len: int8] {.noinit.} =
  ## Parse a LEB128 byte sequence and return value and how many bytes were
  ## parsed - if parsing fails, len <= 0 will be returned - 0 when there are not
  ## enough bytes and -len on overflow, signalling how many bytes were parsed
  let xlen = x.len()
  var
    res: I

  read7(0)
  read7(7)
  read7(14)
  read7(21)
  read7(28)
  read7(35)
  read7(42)
  read7(49)
  read7(56)
  read7(63)

  (I(0), -11'i8)

{.pop.}

template toOpenArray*(v: Leb128Buf): openArray[byte] =
  toOpenArray(v.data, 0, v.len - 1)

template len*(v: Leb128Buf): int8 = v.len
template `@`*(v: Leb128Buf): seq[byte] = @(v.toOpenArray())
iterator items*(v: Leb128Buf): byte =
  for i in 0..<v.len: yield v.data[i]

template fromBytes*(
    I: type SomeUnsignedInt,
    x: Leb128Buf): tuple[val: I, len: int8] =
  # x is not guaranteed to be valid, so we treat it like any other buffer!
  fromBytes(I, x.toOpenArray(), Leb128)

func scan*(
    I: type SomeUnsignedInt,
    x: openArray[byte],
    T: type Leb128): int8 {.noinit.} =
  ## Scan a buffer for a valid leb128-encoded value that at most fits in a
  ## uint64, and report how many bytes it uses
  # TODO this can be done efficiently with SSE
  I.fromBytes(x, Leb128).len

