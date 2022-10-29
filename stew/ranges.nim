{.deprecated: "unattractive memory unsafety - use openArray and other techniques instead".}

when not declared(shallowCopy):
  {.error: "stew/ranges requires shallowCopy (--gc:refc)".}

import
  ranges/memranges,
  ranges/typedranges

export
  memranges, typedranges
