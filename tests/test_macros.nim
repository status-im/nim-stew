import
  unittest,
  ../stew/shims/macros


template unknown() {.pragma.}
template zero() {.pragma.}
template one(one: string) {.pragma.}
template two(one: string, two: string) {.pragma.}

type
  MyType = object
    myField {.zero, one("foo"), two("foo", "bar")}: string

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

let myType = MyType(myField: "test")

suite "Macros":
  test "hasCustomPragmaFixed":
    check:
      not myType.type.hasCustomPragmaFixed("myField", unknown)
      myType.type.hasCustomPragmaFixed("myField", zero)
      myType.type.hasCustomPragmaFixed("myField", one)
      myType.type.hasCustomPragmaFixed("myField", two)
  test "getCustomPragmaFixed":
    check:
      myType.type.getCustomPragmaFixed("myField", unknown).isNil
      myType.type.getCustomPragmaFixed("myField", zero).isNil
      myType.type.getCustomPragmaFixed("myField", one) is string
      myType.type.getCustomPragmaFixed("myField", two) is tuple[one: string, two: string]
