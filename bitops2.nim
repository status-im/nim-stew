const useBuiltins = false
template bitsof*(T: typedesc[SomeInteger]): int = 8 * sizeof(T)
template bitsof*(x: SomeInteger): int = 8 * sizeof(x)
func log2truncNim(x: uint8|uint16|uint32): int =
  const lookup: array[32, uint8] = [0'u8, 9, 1, 10, 13, 21, 2, 29, 11, 14, 16, 18,
    22, 25, 3, 30, 8, 12, 20, 28, 15, 17, 24, 7, 19, 27, 23, 6, 26, 5, 4, 31]
  var v = x.uint32
  v = v or v shr 1
  v = v or v shr 2
  v = v or v shr 4
  v = v or v shr 8
  v = v or v shr 16
  int(lookup[uint32(v * 0x07C4ACDD'u32) shr 27])
func log2truncNim(x: uint64): int =
  const lookup: array[64, uint8] = [0'u8, 58, 1, 59, 47, 53, 2, 60, 39, 48, 27, 54,
    33, 42, 3, 61, 51, 37, 40, 49, 18, 28, 20, 55, 30, 34, 11, 43, 14, 22, 4, 62,
    57, 46, 52, 38, 26, 32, 41, 50, 36, 17, 19, 29, 10, 13, 21, 56, 45, 25, 31,
    35, 16, 9, 12, 44, 24, 15, 8, 23, 7, 6, 5, 63]
  var v = x
  v = v or v shr 1
  v = v or v shr 2
  v = v or v shr 4
  v = v or v shr 8
  v = v or v shr 16
  v = v or v shr 32
  int(lookup[(v * 0x03F6EAF2CD271461'u64) shr 58])
when (defined(gcc) or defined(llvm_gcc) or defined(clang)) and useBuiltins:
  func builtin_clz(x: cuint): cint {.importc: "__builtin_clz", nodecl.}
  func builtin_clzll(x: culonglong): cint {.importc: "__builtin_clzll", nodecl.}
  func log2truncBuiltin(v: uint8|uint16|uint32): int =
    int(31 - cast[cuint](builtin_clz(v.uint32)))
  func log2truncBuiltin(v: uint64): int =
    int(63 - cast[cuint](builtin_clzll(v)))
func log2trunc*(x: SomeUnsignedInt): int {.inline.} =
  if x == 0: -1
  else:
    when nimvm:
      log2truncNim(x)
    else:
      when declared(log2truncBuiltin):
        log2truncBuiltin(x)
      else:
        log2truncNim(x)
func leadingZeros*(x: SomeInteger): int {.inline.} =
  bitsof(x) - 1 - log2trunc(x)
