template init*(lvalue: var auto, args: varargs[typed]) =
  mixin init
  lvalue = init(type(lvalue), args)

