{.deprecated: "use stew/ptrops".}

import ../ptrops
export ptrops

# Please note that we use templates here on purpose.
# As much as I believe in the power of optimizing compilers, it turned
# out that the use of forced inlining with templates still creates a
# significant difference in the release builds of nim-faststreams

template shift*(p: pointer, delta: int): pointer {.deprecated: "use ptrops".} =
  p.offset(delta)

template shift*[T](p: ptr T, delta: int): ptr T {.deprecated: "use ptrops".} =
  p.offset(delta)
