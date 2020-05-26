import
  ../stew/shims/macros

type
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

macro getFieldsLists(T: type): untyped =
  result = newTree(nnkBracket)

  var resolvedType = skipRef getType(T)[1]
  doAssert resolvedType.kind == nnkSym
  var objectType = getImpl(resolvedType)
  doAssert objectType.kind == nnkTypeDef

  for f in recordFields(objectType):
    result.add newLit($f.name)

static:
  doAssert getFieldsLists(DerivedType) == [
    "baseField",
    "baseCaseField",
    "baseA",
    "derivedField"
  ]

