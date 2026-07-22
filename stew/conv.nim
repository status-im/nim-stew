## Explicit canonical conversions between types (`frm` because `from` is a keyword)
##
## `init` is often used to initialize a type, taking other types as arguments -
## however, `frm` and `to` imply conversions rather than initializations - the
## distinction is that the source value is typically "consumed" by the
## conversion wheras `init` might use or initialize itself with the value.
##
## Start by implementing `frm` - the other variations will be derived from it
## if possible. If `frm` is inefficient or impossible, implement `to`, `tryFrm`
## and `tryTo` explicitly.
##
## The `frm` conversion should:
## * always succeed
##   * string-from-int for example
## * work well in the sentence "X was converted from Y"
##
## The `try` forms exist for conversions that might fail:
## * string-to-int (characters might be invalid)
##
## The `to` conversion should:
## * always succeeed
##   * int-to-string for example
## * work well in the sentence "X was converted to Y"
##
## If both `frm` and `to` are implemented, it is expected that they roundtrip
## perfectly.
##
## Optionally, some converters may include a tag - this tag should be passed as
## the last argument:
## * string.frm(15, Hex)

import results, typetraits
export results

type
  Canonical* = object
    # Tag for canonical conversion between types

template frm*(T: type, v: auto): auto = frm(T, v, Canonical)
template tryFrm*(T: type, v: auto): Opt[T] = tryFrm(T, v, Canonical)
template to*(v: auto, T: type): auto = to(v, T, Canonical)
template tryTo*(v: auto, T: type): auto = tryTo(v, T, Canonical)

template frm*(T: type, v: T, tag: type Canonical): T = v

template tryFrm*(T: type, v: auto, tag: typed): auto =
  # Default conversion to T from v
  mixin frm
  when compiles(frm(T, v, tag)):
    ok(Opt[T], frm(T, v, tag))
  else:
    {.error: "Implement frm or tryFrm for " & name(T).}

template to*(v: auto, T: type, tag: typed): auto =
  mixin frm
  when compiles(frm(T, v, tag)):
    frm(T, v, tag)
  else:
    {.error: "Implement to or frm for " & name(T) & " and " & name(typeof(v)).}

template tryTo*(v: auto, T: type, tag: typed): auto =
  mixin frm, tryFrm, to
  when compiles(to(v, T, tag)):
    ok(Opt[T], to(v, T, tag))
  elif compiles(frm(T, v, tag)):
    ok(Opt[T], frm(T, v, tag))
  elif compiles(tryFrm(T, v, tag)):
    tryFrm(T, v, tag)
  else:
    {.error: "Implement to, frm, tryFrm or tryTo for " & name(T).}

template frm*(T: type string, v: SomeInteger, tag: type Canonical): T =
  $v

type AsHex = object
  chars*: int
type AsDefaultHex = object


template asHex*(T: type SomeInteger): auto = AsHex(chars: sizeof(T) * 2)
template asHex*(len: int): auto = AsHex(chars: len)
template asHex*(): auto = AsDefaultHex()

func frm*(T: type string, v: SomeInteger, tag: AsHex): T =
  const
    HexChars = "0123456789abcdef"
  var
    n = v
  var res = newString(tag.chars)
  for j in countdown(res.len-1, 0):
    res[j] = HexChars[int(n and 0xF)]
    n = n shr 4
    # handle negative overflow
    if n == 0 and v < 0: n = -1
  res

template frm*(T: type string, v: SomeInteger, tag: AsDefaultHex): T =
  mixin frm
  frm(T, v, asHex(sizeof(v) * 2))
