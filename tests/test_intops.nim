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

template testMulWiden[T: SomeUnsignedInt]() =
  doAssert mulWiden(T.low, T.low) == (T.low, T.low)
  doAssert mulWiden(T(2), T(2)) == (T(4), T(0))
  doAssert mulWiden(T.high, T(1)) == (T.high, T(0))
  doAssert mulWiden(T(1), T.high) == (T.high, T(0))
  echo mulWiden(T.high, T.high)
  echo T.high
  doAssert mulWiden(T.high, T.high) == (T(1), T.high - 1)

  doAssert mulWiden(T.high, T.high, T(0)) == (T(1), T.high - 1)
  doAssert mulWiden(T.high, T.high, T.high) == (T(0), T.high)

# TODO testMulOverflow

template testMulWiden() =
  testMulWiden[uint8]()
  testMulWiden[uint16]()
  testMulWiden[uint32]()
  testMulWiden[uint64]()
  testMulWiden[uint]()

template test() =
  testAddOverflow()
  testSubOverflow()
  testMulWiden()

static: test()

suite "intops":
  test "test":
    test()
