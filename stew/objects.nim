template init*(lvalue: var auto) =
  mixin init
  lvalue = init(type(lvalue))

template init*(lvalue: var auto, a1: auto)=
  mixin init
  lvalue = init(type(lvalue), a1)

template init*(lvalue: var auto, a1, a2: auto) =
  mixin init
  lvalue = init(type(lvalue), a1, a2)

template init*(lvalue: var auto, a1, a2, a3: auto) =
  mixin init
  lvalue = init(type(lvalue), a1, a2, a3)

when not declared(default):
  proc default*(T: type): T = discard

