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
proc baseType*(obj: RootObj): cstring =
  when not defined(nimTypeNames):
    raiseAssert("you need to compile this with '-d:nimTypeNames'")
  else:
    {.emit: "result = `obj`->m_type->name;".}

proc baseType*(obj: ref RootObj): cstring =
  obj[].baseType

macro enumRangeOrd*(a: type[enum]): untyped =
  ## This macro returns an array with all the ordinal values of an enum
  let
    values = a.getType[1][1..^1]
    valuesOrded = values.mapIt(newCall("ord", it))
  newNimNode(nnkBracket).add(valuesOrded)

proc contains*(e: type[enum], v: SomeInteger): bool =
  v in enumRangeOrd(e)

macro hasHoles*(T: type[enum]): bool =
  # As an enum is always sorted, just substract the first and the last ordinal value
  # and compare the result to the number of element in it will do the trick.
  let
    typ = T.getType[1]
    s = typ[1]
    e = typ[^1]
    len = typ.len - 1

  quote: `e`.ord - `s`.ord == `len`

func checkedEnumAssign*[E: enum, I: SomeInteger](res: var E, value: I): bool =
  ## This function can be used to safely assign a tainted integer value (coming
  ## from untrusted source) to an enum variable. The function will return `true`
  ## if the integer value is within the acceped values of the enum and `false`
  ## otherwise.

  if value notin E:
    return false

  res = E value
  return true

func isZeroMemory*[T](x: T): bool =
  # TODO: iterate over words here
  for b in cast[ptr array[sizeof(T), byte]](unsafeAddr x)[]:
    if b != 0:
      return false
  return true
