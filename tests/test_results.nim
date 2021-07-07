# nim-result is also available stand-alone from https://github.com/arnetheduck/nim-result/

import ../stew/results
type R = Result[int, string]

# Basic usage, producer
func works(): R = R.ok(42)
func works2(): R = result.ok(42)
func fails(): R = R.err("dummy")
func fails2(): R = result.err("dummy")

func raises(): int =
  raise (ref CatchableError)(msg: "hello")

# Basic usage, consumer
let
  rOk = works()
  rOk2 = works2()
  rErr = fails()
  rErr2 = fails2()

doAssert rOk.isOk
doAssert rOk2.isOk
doAssert rOk.get() == 42
doAssert (not rOk.isErr)
doAssert rErr.isErr
doAssert rErr2.isErr

# Combine
doAssert (rOk and rErr).isErr
doAssert (rErr and rOk).isErr
doAssert (rOk or rErr).isOk
doAssert (rErr or rOk).isOk

# `and` heterogenous types
doAssert (rOk and rOk.map(proc(x: auto): auto = $x))[] == $(rOk[])

# `or` heterogenous types
doAssert (rErr or rErr.mapErr(proc(x: auto): auto = len(x))).error == len(rErr.error)

# Exception on access
let va = try: discard rOk.error; false except: true
doAssert va, "not an error, should raise"

# Exception on access
let vb = try: discard rErr.value; false except: true
doAssert vb, "not an value, should raise"

var x = rOk

# Mutate
x.err("failed now")

doAssert x.isErr

# Exceptions -> results
let c = catch:
  raises()

doAssert c.isErr

# De-reference
try:
  echo rErr[]
  doAssert false
except:
  discard

doAssert rOk.valueOr(50) == rOk.value
doAssert rErr.valueOr(50) == 50

# Comparisons
doAssert (works() == works2())
doAssert (fails() == fails2())
doAssert (works() != fails())

var counter = 0
proc incCounter(): R =
  counter += 1
  R.ok(counter)

doAssert (rErr and incCounter()).isErr, "b fails"
doAssert counter == 0, "should fail fast on rErr"

# Mapping
doAssert (rOk.map(func(x: int): string = $x)[] == $rOk.value)
doAssert (rOk.flatMap(
  proc(x: int): Result[string, string] = Result[string, string].ok($x))[] == $rOk.value)
doAssert (rErr.mapErr(func(x: string): string = x & "no!").error == (rErr.error & "no!"))

# Exception interop
let e = capture(int, (ref ValueError)(msg: "test"))
doAssert e.isErr
doAssert e.error.msg == "test"

try:
  discard e.tryGet
  doAssert false, "should have raised"
except ValueError as e:
  doAssert e.msg == "test"

# Nice way to checks
if (let v = works(); v.isOk):
  doAssert v[] == v.value

# Can formalise it into a template (https://github.com/arnetheduck/nim-result/issues/8)
template `?=`*(v: untyped{nkIdent}, vv: Result): bool =
  (let vr = vv; template v: auto {.used.} = unsafeGet(vr); vr.isOk)
if f ?= works():
  doAssert f == works().value

doAssert $rOk == "Ok(42)"

doAssert rOk.mapConvert(int64)[] == int64(42)
doAssert rOk.mapCast(int8)[] == int8(42)
doAssert rOk.mapConvert(uint64)[] == uint64(42)

try:
  discard rErr.get()
  doAssert false
except Defect: # TODO catching defects is undefined behaviour, use external test suite?
  discard

try:
  discard rOk.error()
  doAssert false
except Defect: # TODO catching defects is undefined behaviour, use external test suite?
  discard

# TODO there's a bunch of operators that one could lift through magic - this
#      is mainly an example
template `+`*(self, other: Result): untyped =
  ## Perform `+` on the values of self and other, if both are ok
  type R = type(other)
  if self.isOk:
    if other.isOk:
      R.ok(self.value + other.value)
    else:
      R.err(other.error)
  else:
    R.err(self.error)

# Simple lifting..
doAssert (rOk + rOk)[] == rOk.value + rOk.value

iterator items[T, E](self: Result[T, E]): T =
  ## Iterate over result as if it were a collection of either 0 or 1 items
  ## TODO should a Result[seq[X]] iterate over items in seq? there are
  ##      arguments for and against
  if self.isOk:
    yield self.value

# Iteration
var counter2 = 0
for v in rOk:
  counter2 += 1

doAssert counter2 == 1, "one-item collection when set"

func testOk(): Result[int, string] =
  ok 42

func testErr(): Result[int, string] =
  err "323"

doAssert testOk()[] == 42
doAssert testErr().error == "323"

doAssert testOk().expect("testOk never fails") == 42

func testQn(): Result[int, string] =
  let x = ?works() - ?works()
  result.ok(x)

func testQn2(): Result[int, string] =
  # looks like we can even use it creatively like this
  if ?fails() == 42: raise (ref ValueError)(msg: "shouldn't happen")

func testQn3(): Result[bool, string] =
  # different T but same E
  let x = ?works() - ?works()
  result.ok(x == 0)

doAssert testQn()[] == 0
doAssert testQn2().isErr
doAssert testQn3()[]

proc heterOr(): Result[int, int] =
  let value = ? (rErr or err(42))  # TODO ? binds more tightly than `or` - can that be fixed?
  doAssert value + 1 == value, "won't reach, ? will shortcut execution"
  ok(value)

doAssert heterOr().error() == 42

type
  AnEnum = enum
    anEnumA
    anEnumB
  AnException = ref object of CatchableError
    v: AnEnum

func toException(v: AnEnum): AnException = AnException(v: v)

func testToException(): int =
  try:
    var r = Result[int, AnEnum].err(anEnumA)
    r.tryGet
  except AnException:
    42

doAssert testToException() == 42

type
  AnEnum2 = enum
    anEnum2A
    anEnum2B

func testToString(): int =
  try:
    var r = Result[int, AnEnum2].err(anEnum2A)
    r.tryGet
  except ResultError[AnEnum2]:
    42

doAssert testToString() == 42

type VoidRes = Result[void, int]

func worksVoid(): VoidRes = VoidRes.ok()
func worksVoid2(): VoidRes = result.ok()
func failsVoid(): VoidRes = VoidRes.err(42)
func failsVoid2(): VoidRes = result.err(42)

let
  vOk = worksVoid()
  vOk2 = worksVoid2()
  vErr = failsVoid()
  vErr2 = failsVoid2()

doAssert vOk.isOk
doAssert vOk2.isOk
doAssert vErr.isErr
doAssert vErr2.isErr

vOk.get()
vOk.expect("should never fail")

doAssert vOk.map(proc (): int = 42).get() == 42

rOk.map(proc(x: int) = discard).get()

try:
  rErr.map(proc(x: int) = discard).get()
  doAssert false
except:
  discard

doAssert vErr.mapErr(proc(x: int): int = 10).error() == 10

func voidF(): VoidRes =
  ok()

func voidF2(): VoidRes =
  ? voidF()

  ok()

doAssert voidF2().isOk


type CSRes = Result[void, cstring]

func cstringF(s: string): CSRes =
  when compiles(err(s)):
    doAssert false

discard cstringF("test")

# Compare void
block:
  var a, b: Result[void, bool]
  doAssert a == b

  a.ok()

  doAssert not (a == b)
  doAssert not (b == a)

  b.ok()

  doAssert a == b
