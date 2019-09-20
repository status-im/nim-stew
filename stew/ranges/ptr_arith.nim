import ../ptrops
export ptrops

proc baseAddr*[T](x: openarray[T]): pointer = cast[pointer](x)

# Please note that we use templates here on purpose.
# As much as I believe in the power of optimizing compilers, it turned
# out that the use of forced inlining with templates still creates a
# significant difference in the release builds of nim-faststreams

template shift*(p: pointer, delta: int): pointer {.deprecated: "use ptrops".} =
  p.offset(delta)

template shift*[T](p: ptr T, delta: int): ptr T {.deprecated: "use ptrops".} =
  p.offset(delta)

when (NimMajor,NimMinor,NimPatch) >= (0,19,9):
  template makeOpenArray*[T](p: ptr T, len: int): auto =
    toOpenArray(cast[ptr UncheckedArray[T]](p), 0, len - 1)

  template makeOpenArray*(p: pointer, T: type, len: int): auto =
    toOpenArray(cast[ptr UncheckedArray[T]](p), 0, len - 1)

elif (NimMajor,NimMinor,NimPatch) >= (0,19,0):
  # TODO: These are fallbacks until we upgrade to 0.19.9
  template makeOpenArray*(p: pointer, T: type, len: int): auto =
    toOpenArray(cast[ptr array[0, T]](p)[], 0, len - 1)

  template makeOpenArray*[T](p: ptr T, len: int): auto =
    toOpenArray(cast[ptr array[0, T]](p)[], 0, len - 1)
