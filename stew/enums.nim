import
  macros, sequtils

macro enumRangeInt64*(a: type[enum]): untyped =
  ## This macro returns an array with all the ordinal values of an enum
  let
    values = a.getType[1][1..^1]
    valuesOrded = values.mapIt(newCall("int64", it))
  newNimNode(nnkBracket).add(valuesOrded)

macro enumStrValuesArrayImpl(a: type[enum]): untyped =
  ## This macro returns an array with all the ordinal values of an enum
  let
    values = a.getType[1][1..^1]
    valuesOrded = values.mapIt(newCall("$", it))
  newNimNode(nnkBracket).add(valuesOrded)

# TODO: This should be a proc returning a lent view over the
#       const value. This will ensure only a single instace
#       of the array is generated.
template enumStrValuesArray*(E: type[enum]): auto =
  const values = enumStrValuesArrayImpl E
  values

# TODO: This should be a proc returning a lent view over the
#       const value. This will ensure only a single instace
#       of the sequence is generated.
template enumStrValuesSeq*(E: type[enum]): seq[string] =
  const values = @(enumStrValuesArray E)
  values

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

  res = E value
  return true
