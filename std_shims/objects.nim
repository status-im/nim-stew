template init*(lvalue: var auto, args: varargs[untyped]) =
  mixin init
  lvalue = init(type(lvalue), args)

