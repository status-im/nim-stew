type SomeEndianInt* = uint8|uint16|uint32|uint64
const useBuiltins = not defined(noIntrinsicsEndians)
when (defined(gcc) or defined(llvm_gcc) or defined(clang)) and useBuiltins:
  func swapBytesBuiltin(x: uint8): uint8 = x
  func swapBytesBuiltin(x: uint16): uint16 {.importc: "__builtin_bswap16", nodecl.}
  func swapBytesBuiltin(x: uint32): uint32 {.importc: "__builtin_bswap32", nodecl.}
  func swapBytesBuiltin(x: uint64): uint64 {.importc: "__builtin_bswap64", nodecl.}
func swapBytesNim(x: uint8): uint8 = x
func swapBytesNim(x: uint16): uint16 = (x shl 8) or (x shr 8)
func swapBytesNim(x: uint32): uint32 =
  let v = (x shl 16) or (x shr 16)
  ((v shl 8) and 0xff00ff00'u32) or ((v shr 8) and 0x00ff00ff'u32)
func swapBytesNim(x: uint64): uint64 =
  var v = (x shl 32) or (x shr 32)
  v = ((v and 0x0000ffff0000ffff'u64) shl 16) or ((v and 0xffff0000ffff0000'u64) shr 16)
  ((v and 0x00ff00ff00ff00ff'u64) shl 8) or ((v and 0xff00ff00ff00ff00'u64) shr 8)
func swapBytes*[T: SomeEndianInt](x: T): T {.inline.} =
  when nimvm:
    swapBytesNim(x)
  else:
    when declared(swapBytesBuiltin):
      swapBytesBuiltin(x)
    else:
      swapBytesNim(x)
func toBytes*(x: SomeEndianInt, endian: Endianness = system.cpuEndian):
    array[sizeof(x), byte] {.noinit, inline.} =
  let v =
    if endian == system.cpuEndian: x
    else: swapBytes(x)
  when nimvm:
    for i in 0..<sizeof(result):
      result[i] = byte((v shr (i * 8)) and 0xff)
  else:
    copyMem(addr result, unsafeAddr v, sizeof(result))
func toBytesBE*(x: SomeEndianInt):
    array[sizeof(x), byte] {.inline.} =
  toBytes(x, bigEndian)
