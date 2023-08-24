## This module may hold various saturating arithmetic definitions.
## It will be expanded on demand as more definitions are requred.

func saturate*(T: type int64, u: uint64): T =
  if u > high(int64).uint64:
    high(int64)
  else:
    int64(u)
