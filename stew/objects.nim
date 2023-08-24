import
  macros,
  sequtils

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

proc toArray*[T](N: static int, data: openArray[T]): array[N, T] =
  doAssert data.len == N
  copyMem(addr result[0], unsafeAddr data[0], N)

template anonConst*(val: untyped): untyped =
  const c = val
  c

func declval*(T: type): T {.compileTime.} =
  ## `declval` denotes an anonymous expression of a particular
  ## type. It can be used in situations where you want to determine
  ## the type of an overloaded call in `typeof` expressions.
  ##
  ## Example:
  ## ```
  ## type T = typeof foo(declval(string), declval(var int))
  ## ```
  ##
  ## Please note that `declval` has two advantages over `default`:
  ##
  ## 1. It can return expressions with proper `var` or `lent` types.
  ##
  ## 2. It will work for types that lack a valid default value due
  ##    to `not nil` or `requiresInit` requirements.
  ##
  doAssert false,
    "declval should be used only in `typeof` expressions and concepts"
  default(ptr T)[]

when not compiles(len((1, 2))):
  import typetraits

  func len*(x: tuple): int =
    arity(type(x))

# Get an object's base type, as a cstring. Ref objects will have an ":ObjectType"
# suffix.
# From: https://gist.github.com/stefantalpalaru/82dc71bb547d6f9178b916e3ed5b527d
when not defined(nimTypeNames):
  proc baseType*(obj: RootObj): cstring {.error: "baseType requires -d:nimTypeNames".}
  proc baseType*(obj: ref RootObj): cstring {.error: "baseType requires -d:nimTypeNames".}
elif defined(gcArc) or defined(gcOrc):
  proc baseType*(obj: RootObj): cstring {.error: "baseType is not available in ARC/ORC".}
  proc baseType*(obj: ref RootObj): cstring {.error: "baseType is not available in ARC/ORC".}
else:
  proc baseType*(obj: RootObj): cstring {.deprecated.} =
    {.emit: "result = `obj`->m_type->name;".}

  proc baseType*(obj: ref RootObj): cstring {.deprecated.} =
    obj[].baseType

macro enumRangeInt64*(a: type[enum]): untyped =
  ## This macro returns an array with all the ordinal values of an enum
  let
    values = a.getType[1][1..^1]
    valuesOrded = values.mapIt(newCall("int64", it))
  newNimNode(nnkBracket).add(valuesOrded)

macro hasHoles*(T: type[enum]): bool =
  # As an enum is always sorted, just substract the first and the last ordinal value
  # and compare the result to the number of element in it will do the trick.
  let len = T.getType[1].len - 2

  quote: `T`.high.ord - `T`.low.ord != `len`

proc contains*[I: SomeInteger](e: type[enum], v: I): bool =
  when I is uint64:
    if v > int.high.uint64:
      return false
  when e.hasHoles():
    v.int64 in enumRangeInt64(e)
  else:
    v.int64 in e.low.int64 .. e.high.int64

func checkedEnumAssign*[E: enum, I: SomeInteger](res: var E, value: I): bool =
  ## This function can be used to safely assign a tainted integer value (coming
  ## from untrusted source) to an enum variable. The function will return `true`
  ## if the integer value is within the acceped values of the enum and `false`
  ## otherwise.

  if value notin E:
    return false

  res = cast[E](value)
  return true

func isZeroMemory*[T](x: T): bool =
  # TODO: iterate over words here
  for b in cast[ptr array[sizeof(T), byte]](unsafeAddr x)[]:
    if b != 0:
      return false
  return true

func isDefaultValue*[T](x: T): bool =
  # TODO: There are ways to optimise this for simple POD types
  #       (they can be mapped to `isZeroMemory`)
  #       It may also be beneficial to store the RHS in a const.
  #       Check the codegen.
  x == default(T)
