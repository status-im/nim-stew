when (NimMajor, NimMinor) < (1, 4):
  type
    AccessViolationDefect* = AccessViolationError
    ArithmeticDefect* = ArithmeticError
    AssertionDefect* = AssertionError
    DeadThreadDefect* = DeadThreadError
    DivByZeroDefect* = DivByZeroError
    FieldDefect* = FieldError
    FloatDivByZeroDefect* = FloatDivByZeroError
    FloatInexactDefect* = FloatInexactError
    FloatInvalidOpDefect* = FloatInvalidOpError
    FloatOverflowDefect* = FloatOverflowError
    FloatUnderflowDefect* = FloatUnderflowError
    FloatingPointDefect* = FloatingPointError
    IndexDefect* = IndexError
    NilAccessDefect* = NilAccessError
    ObjectAssignmentDefect* = ObjectAssignmentError
    ObjectConversionDefect* = ObjectConversionError
    OutOfMemDefect* = OutOfMemError
    OverflowDefect* = OverflowError
    RangeDefect* = RangeError
    ReraiseDefect* = ReraiseError
    StackOverflowDefect* = StackOverflowError
else:
  {.used.}
