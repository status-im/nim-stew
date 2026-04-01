## This module may hold various saturating arithmetic definitions.
## It will be expanded on demand as more definitions are requred.

{.deprecated: "Use https://github.com/vacp2p/nim-intops instead".}

func saturate*(T: type int64, u: uint64): T =
  ##[ Convert a uint64 to int64. If the value won't fit in int64,
  return maximal value.

  Notice: This function is deprecated.

  If you need to limit the value of an integer, use `clamp(a, minVal, maxVal)` from stdlib.

  If you use this function to implement saturating addition, use `saturatingAdd` from [intops](https://github.com/vacp2p/nim-intops/) library.
  ]##

  if u > high(int64).uint64:
    high(int64)
  else:
    int64(u)
