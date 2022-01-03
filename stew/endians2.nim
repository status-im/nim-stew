# Copyright (c) 2018-2019 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# Endian conversion operations for unsigned integers, suitable for serializing
# and deserializing data. The operations are only defined for unsigned
# integers - if you wish to encode signed integers, convert / cast them to
# unsigned first!
#
# Although it would be possible to enforce correctness with endians in the type
# (`BigEndian[uin64]`) this seems like overkill. That said, some
# static analysis tools allow you to annotate fields with endianness - perhaps
# an idea for the future, akin to `TaintedString`?
#
# Keeping the above in mind, it's generally safer to use `array[N, byte]` to
# hold values of specific endianness and read them out with `fromBytes` when the
# integer interpretation of the bytes is needed.

{.push raises: [].}

type
  SomeEndianInt* = uint8|uint16|uint32|uint64
    ## types that we support endian conversions for - uint8 is there for
    ## for syntactic / generic convenience. Other candidates:
    ## * int/uint - uncertain size, thus less suitable for binary interop
    ## * intX - over and underflow protection in nim might easily cause issues -
    ##          need to consider before adding here

const
  useBuiltins = not defined(noIntrinsicsEndians)

when (defined(gcc) or defined(llvm_gcc) or defined(clang)) and useBuiltins:
  func swapBytesBuiltin(x: uint8): uint8 = x
  func swapBytesBuiltin(x: uint16): uint16 {.
      importc: "__builtin_bswap16", nodecl.}

  func swapBytesBuiltin(x: uint32): uint32 {.
      importc: "__builtin_bswap32", nodecl.}

  func swapBytesBuiltin(x: uint64): uint64 {.
      importc: "__builtin_bswap64", nodecl.}

elif defined(icc) and useBuiltins:
  func swapBytesBuiltin(x: uint8): uint8 = x
  func swapBytesBuiltin(a: uint16): uint16 {.importc: "_bswap16", nodecl.}
  func swapBytesBuiltin(a: uint32): uint32 {.importc: "_bswap", nodec.}
  func swapBytesBuiltin(a: uint64): uint64 {.importc: "_bswap64", nodecl.}

elif defined(vcc) and useBuiltins:
  func swapBytesBuiltin(x: uint8): uint8 = x
  func swapBytesBuiltin(a: uint16): uint16 {.
      importc: "_byteswap_ushort", cdecl, header: "<intrin.h>".}

  func swapBytesBuiltin(a: uint32): uint32 {.
      importc: "_byteswap_ulong", cdecl, header: "<intrin.h>".}

  func swapBytesBuiltin(a: uint64): uint64 {.
      importc: "_byteswap_uint64", cdecl, header: "<intrin.h>".}

func swapBytesNim(x: uint8): uint8 = x
func swapBytesNim(x: uint16): uint16 = (x shl 8) or (x shr 8)

func swapBytesNim(x: uint32): uint32 =
  let v = (x shl 16) or (x shr 16)

  ((v shl 8) and 0xff00ff00'u32) or ((v shr 8) and 0x00ff00ff'u32)

func swapBytesNim(x: uint64): uint64 =
  var v = (x shl 32) or (x shr 32)
  v =
    ((v and 0x0000ffff0000ffff'u64) shl 16) or
    ((v and 0xffff0000ffff0000'u64) shr 16)

  ((v and 0x00ff00ff00ff00ff'u64) shl 8) or
    ((v and 0xff00ff00ff00ff00'u64) shr 8)

func swapBytes*[T: SomeEndianInt](x: T): T {.inline.} =
  ## Reverse the bytes within an integer, such that the most significant byte
  ## changes place with the least significant one, etc
  ##
  ## Example:
  ## doAssert swapBytes(0x01234567'u32) == 0x67452301
  when nimvm:
    swapBytesNim(x)
  else:
    when declared(swapBytesBuiltin):
      swapBytesBuiltin(x)
    else:
      swapBytesNim(x)

func toBytes*(x: SomeEndianInt, endian: Endianness = system.cpuEndian):
    array[sizeof(x), byte] {.noinit, inline.} =
  ## Convert integer to its corresponding byte sequence using the chosen
  ## endianness. By default, native endianness is used which is not portable!
  let v =
    if endian == system.cpuEndian: x
    else: swapBytes(x)

  when nimvm: # No copyMem in vm
    for i in 0..<sizeof(result):
      result[i] = byte((v shr (i * 8)) and 0xff)
  else:
    copyMem(addr result, unsafeAddr v, sizeof(result))

func toBytesLE*(x: SomeEndianInt):
    array[sizeof(x), byte] {.inline.} =
  ## Convert a native endian integer to a little endian byte sequence
  toBytes(x, littleEndian)

func toBytesBE*(x: SomeEndianInt):
    array[sizeof(x), byte] {.inline.} =
  ## Convert a native endian integer to a native endian byte sequence
  toBytes(x, bigEndian)

func fromBytes*(
    T: typedesc[SomeEndianInt],
    x: openArray[byte],
    endian: Endianness = system.cpuEndian): T {.inline.} =
  ## Read bytes and convert to an integer according to the given endianness.
  ##
  ## Note: The default value of `system.cpuEndian` is not portable across
  ## machines.
  ##
  ## Panics when `x.len < sizeof(T)` - for shorter buffers, copy the data to
  ## an `array` first using `arrayops.initCopyFrom`, taking care to zero-fill
  ## at the right end - usually the beginning for big endian and the end for
  ## little endian, but this depends on the serialization of the bytes.

  # This check gets optimized away when the compiler can prove that the length
  # is large enough - passing in an `array` or using a construct like
  # ` toOpenArray(pos, pos + sizeof(T) - 1)` are two ways that this happens
  doAssert x.len >= sizeof(T), "Not enough bytes for endian conversion"

  when nimvm: # No copyMem in vm
    for i in 0..<sizeof(result):
      result = result or (T(x[i]) shl (i * 8))
  else:
    # `copyMem` helps compilers optimize the copy into a single instruction, when
    # alignment etc permits
    copyMem(addr result, unsafeAddr x[0], sizeof(result))

  if endian != system.cpuEndian:
    # The swap is turned into a CPU-specific instruction and/or combined with
    # the copy above, again when conditions permit it - for example, on X86
    # fromBytesBE gets compiled into a single `MOVBE` instruction
    result = swapBytes(result)

func fromBytesBE*(
    T: typedesc[SomeEndianInt],
    x: openArray[byte]): T {.inline.} =
  ## Read big endian bytes and convert to an integer. At runtime, v must contain
  ## at least sizeof(T) bytes. By default, native endianness is used which is
  ## not portable!
  fromBytes(T, x, bigEndian)

func toBE*[T: SomeEndianInt](x: T): T {.inline.} =
  ## Convert a native endian value to big endian. Consider toBytesBE instead
  ## which may prevent some confusion.
  if cpuEndian == bigEndian: x
  else: x.swapBytes

func fromBE*[T: SomeEndianInt](x: T): T {.inline.} =
  ## Read a big endian value and return the corresponding native endian
  # there's no difference between this and toBE, except when reading the code
  toBE(x)

func fromBytesLE*(
    T: typedesc[SomeEndianInt],
    x: openArray[byte]): T {.inline.} =
  ## Read little endian bytes and convert to an integer. At runtime, v must
  ## contain at least sizeof(T) bytes. By default, native endianness is used
  ## which is not portable!
  fromBytes(T, x, littleEndian)

func toLE*[T: SomeEndianInt](x: T): T {.inline.} =
  ## Convert a native endian value to little endian. Consider toBytesLE instead
  ## which may prevent some confusion.
  if cpuEndian == littleEndian: x
  else: x.swapBytes

func fromLE*[T: SomeEndianInt](x: T): T {.inline.} =
  ## Read a little endian value and return the corresponding native endian
  # there's no difference between this and toLE, except when reading the code
  toLE(x)
