import unittest2

import ../stew/intops

template testAddOverflow[T: SomeUnsignedInt]() =
  doAssert addOverflow(T.low, T.low) == (T.low, false)
  doAssert addOverflow(T.high, T.low) == (T.high, false)
  doAssert addOverflow(T.low, T.high) == (T.high, false)

  doAssert addOverflow(T.high, T.high) == (T.high - 1, true)

  doAssert addOverflow(T.high, T(0), false) == (T.high, false)
  doAssert addOverflow(T.high, T(0), true) == (T(0), true)
  doAssert addOverflow(T.high, T.high, true) == (T.high, true)

template testSubOverflow[T: SomeUnsignedInt]() =
  doAssert subOverflow(T.low, T.low) == (T.low, false)
  doAssert subOverflow(T.high, T.low) == (T.high, false)
  doAssert subOverflow(T.high, T.high) == (T.low, false)

  doAssert subOverflow(T.low, T.high) == (T(1), true)

  doAssert subOverflow(T.high, T.high, false) == (T(0), false)
  doAssert subOverflow(T.high, T.high, true) == (T.high, true)

template testAddSaturated[T: SomeUnsignedInt]() =
  doAssert addSaturated(T(100), T(1)) == T(101)
  doAssert addSaturated(T.high, T(127)) == T.high

template testSubSaturated[T: SomeUnsignedInt] =
  doAssert subSaturated(T(100), T(27)) == T(73)
  doAssert subSaturated(T(13), T(127)) == T.low
  
template testAddOverflow() =
  testAddOverflow[uint8]()
  testAddOverflow[uint16]()
  testAddOverflow[uint32]()
  testAddOverflow[uint64]()
  testAddOverflow[uint]()

template testSubOverflow() =
  testSubOverflow[uint8]()
  testSubOverflow[uint16]()
  testSubOverflow[uint32]()
  testSubOverflow[uint64]()
  testSubOverflow[uint]()

template testAddSaturated() =
  testAddSaturated[uint8]()
  testAddSaturated[uint16]()
  testAddSaturated[uint32]()
  testAddSaturated[uint64]()
  testAddSaturated[uint]()

template testSubSaturated() =
  testSubSaturated[uint8]()
  testSubSaturated[uint16]()
  testSubSaturated[uint32]()
  testSubSaturated[uint64]()
  testSubSaturated[uint]()

template testMulWiden[T: SomeUnsignedInt]() =
  doAssert mulWiden(T.low, T.low) == (T.low, T.low)
  doAssert mulWiden(T(2), T(2)) == (T(4), T(0))
  doAssert mulWiden(T.high, T(1)) == (T.high, T(0))
  doAssert mulWiden(T(1), T.high) == (T.high, T(0))
  doAssert mulWiden(T.high, T.high) == (T(1), T.high - 1)

  doAssert mulWiden(T.high, T.high, T(0)) == (T(1), T.high - 1)
  doAssert mulWiden(T.high, T.high, T.high) == (T(0), T.high)

template testMulSaturated[T: SomeUnsignedInt]() =
  doAssert mulSaturated(T(100), T(2)) == T(200)
  doAssert mulSaturated(T.high, T(10)) == T.high

template testMulSaturated() =
  testMulSaturated[uint8]()
  testMulSaturated[uint16]()
  testMulSaturated[uint32]()
  testMulSaturated[uint64]()
  testMulSaturated[uint]()


template testMulWiden() =
  testMulWiden[uint8]()
  testMulWiden[uint16]()
  testMulWiden[uint32]()
  testMulWiden[uint64]()
  testMulWiden[uint]()

template test() =
  testAddOverflow()
  testSubOverflow()
  testAddSaturated()
  testSubSaturated()
  testMulWiden()
  testMulSaturated()

static: test()

suite "intops":
  test "test":
    test()
