import
  ../stew/conv

type
  Obj = object
    v: int

  HasFrm = object
    v: int

  HasTo = object
    v: int

  HasTryFrom = object
    v: int

  HasTryTo = object
    v: int

template frm(T: type HasFrm, o: Obj, tag = Canonical): T = T(v: o.v)

let o = Obj(v: 42)

let
  hft = o.to(HasFrm)
  hff = HasFrm.frm(o)
  hftf = HasFrm.tryFrm(o)
  hftt = o.tryTo(HasFrm)

doAssert hff.v == o.v
doAssert hftf.get().v == o.v
doAssert hft.v == o.v
doAssert hftt.get().v == o.v

doAssert (string.frm(42) == "42")
doAssert string.tryFrm(42)[] == "42"
doAssert 42.to(string) == "42"
doAssert 42.tryTo(string)[] == "42"

doAssert string.frm(10, asHex(4)) == "000a"
doAssert 10.to(string, asHex(int16)) == "000a"
doAssert 10'i16.to(string, asHex()) == "000a"
