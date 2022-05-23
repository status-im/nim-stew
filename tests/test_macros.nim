import
  unittest,
  ../stew/shims/macros


template unknown() {.pragma.}
template zero() {.pragma.}
template one(one: string) {.pragma.}
template two(one: string, two: string) {.pragma.}

type
  MyType[T] = object
    myField {.zero, one("foo"), two("foo", "bar")}: string
    myGeneric {.zero.}: T
    case kind {.zero.}: bool
      of true:
        first {.zero.}: string
      else:
        second {.zero.}: string

  FieldKind = enum
    KindA
    KindB

  BaseType = object of RootObj
    baseField: int
    case baseCaseField: FieldKind
    of KindA:
      baseA: int
    of KindB:
      discard

  DerivedType = ref object of BaseType
    derivedField: int

  DerivedFromRefType = ref object of DerivedType
    anotherDerivedField: string

macro getFieldsLists(T: type): untyped =
  result = newTree(nnkBracket)

  var resolvedType = skipRef getType(T)[1]
  doAssert resolvedType.kind == nnkSym
  var objectType = getImpl(resolvedType)
  doAssert objectType.kind == nnkTypeDef

  for f in recordFields(objectType):
    result.add newLit($f.name)

static:
  doAssert getFieldsLists(DerivedFromRefType) == [
    "baseField",
    "baseCaseField",
    "baseA",
    "derivedField",
    "anotherDerivedField"
  ]

let myType = MyType[string](myField: "test", myGeneric: "test", kind: true, first: "test")

suite "Macros":
  test "hasCustomPragmaFixed":
    check:
      not myType.type.hasCustomPragmaFixed("myField", unknown)
      myType.type.hasCustomPragmaFixed("myField", zero)
      myType.type.hasCustomPragmaFixed("myField", one)
      myType.type.hasCustomPragmaFixed("myField", two)

      myType.type.hasCustomPragmaFixed("myGeneric", zero)
      myType.type.hasCustomPragmaFixed("kind", zero)
      myType.type.hasCustomPragmaFixed("first", zero)
      myType.type.hasCustomPragmaFixed("second", zero)

  test "getCustomPragmaFixed":
    check:
      myType.type.getCustomPragmaFixed("myField", unknown).isNil
      myType.type.getCustomPragmaFixed("myField", zero).isNil
      myType.type.getCustomPragmaFixed("myField", one) is string
      myType.type.getCustomPragmaFixed("myField", two) is tuple[one: string, two: string]

      myType.type.getCustomPragmaFixed("myGeneric", zero).isNil
      myType.type.getCustomPragmaFixed("kind", zero).isNil
      myType.type.getCustomPragmaFixed("first", zero).isNil
      myType.type.getCustomPragmaFixed("second", zero).isNil
