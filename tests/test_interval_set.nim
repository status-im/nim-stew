# Nimbus - Types, data structures and shared utilities used in network sync
#
# Copyright (c) 2018-2022 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or
# distributed except according to those terms.

{.used.}

import
  unittest2,
  ../stew/interval_set

const
  # needs additional import, so this is not standard
  TestFrBlockBNumberAlikeOk = false

when TestFrBlockBNumberAlikeOk:
  import stint
  type FancyScalar = UInt256 # instead of BlockNumber
else:
  type FancyScalar = uint64


type
  FancyPoint = distinct FancyScalar
  FancyRanges = IntervalSetRef[FancyPoint,FancyScalar]
  FancyInterval = Interval[FancyPoint,FancyScalar]

const
  uHigh = high(uint64)
  uLow = low(uint64)

let
  ivError = IntervalRc[FancyPoint,FancyScalar].err()

# ------------------------------------------------------------------------------
# Private data type cast helpers
# ------------------------------------------------------------------------------

when 8 < sizeof(FancyScalar): # assuming UInt256:
  proc to(num: uint64; T: type FancyScalar): T = num.u256.T
  proc to(num: uint64; T: type FancyPoint): T = num.to(FancyScalar).T
else:
  proc to(num: uint64; T: type FancyPoint): T = num.T
  proc to(num: uint64; T: type FancyScalar): T = num.T
  proc truncate(num: FancyScalar; T: type uint64): T = num

# ------------------------------------------------------------------------------
# Private data type interface for `IntervalSet` implementation
# ------------------------------------------------------------------------------

# use a sub-range for `FancyPoint` elements
proc high(T: type FancyPoint): T = uHigh.to(FancyPoint)
proc low(T: type FancyPoint): T = uLow.to(FancyPoint)

proc to(num: FancyPoint; T: type FancyScalar): T = num.T
proc `$`(num: FancyPoint): string = $num.to(FancyScalar)

proc `+`*(a: FancyPoint; b: FancyScalar): FancyPoint =
  (a.to(FancyScalar) + b).FancyPoint

proc `-`*(a: FancyPoint; b: FancyScalar): FancyPoint =
  (a.to(FancyScalar) - b).FancyPoint

proc `-`*(a, b: FancyPoint): FancyScalar =
  (a.to(FancyScalar) - b.to(FancyScalar))

proc `==`*(a, b: FancyPoint): bool = a.to(FancyScalar) == b.to(FancyScalar)
proc `<=`*(a, b: FancyPoint): bool = a.to(FancyScalar) <= b.to(FancyScalar)
proc `<`*(a, b: FancyPoint): bool = a.to(FancyScalar) < b.to(FancyScalar)

# ------------------------------------------------------------------------------
# Private functions
# ------------------------------------------------------------------------------

proc truncate(num: FancyPoint; T: type uint64): uint64 =
  num.to(FancyScalar).truncate(uint64)

proc merge(br: FancyRanges; left, right: uint64): uint64 =
  let (a, b) = (left.to(FancyPoint), right.to(FancyPoint))
  br.merge(a, b).truncate(uint64)

proc reduce(br: FancyRanges; left, right: uint64): uint64 =
  let (a, b) = (left.to(FancyPoint), right.to(FancyPoint))
  br.reduce(a, b).truncate(uint64)

proc covered(br: FancyRanges; left, right: uint64): uint64 =
  let (a, b) = (left.to(FancyPoint), right.to(FancyPoint))
  br.covered(a, b).truncate(uint64)

proc delete(br: FancyRanges; start: uint64): Result[FancyInterval,void] =
  br.delete(start.to(FancyPoint))

proc le(br: FancyRanges; start: uint64): Result[FancyInterval,void] =
  br.le(start.to(FancyPoint))

proc ge(br: FancyRanges; start: uint64): Result[FancyInterval,void] =
  br.ge(start.to(FancyPoint))

proc envelope(br: FancyRanges; start: uint64): Result[FancyInterval,void] =
  br.envelope(start.to(FancyPoint))

proc iv(left, right: uint64): FancyInterval =
  FancyInterval.new(left.to(FancyPoint), right.to(FancyPoint))

# ------------------------------------------------------------------------------
# Test Runner
# ------------------------------------------------------------------------------

suite "IntervalSet: Intervals of FancyPoint entries over FancyScalar":
  let br = FancyRanges.init()
  var dup: FancyRanges

  test "Verify max interval handling":
    br.clear()
    check br.merge(0,uHigh) == 0
    check br.chunks == 1
    check br.total == 0
    check br.verify.isOk

    check br.reduce(uHigh,uHigh) == 1
    check br.chunks == 1
    check br.total == uHigh.to(FancyScalar)
    check br.verify.isOk

  test "Verify handling of maximal interval points (edge cases)":
    br.clear()
    check br.merge(0,uHigh) == 0
    check br.reduce(uHigh-1,uHigh-1) == 1
    check br.verify.isOk
    check br.chunks == 2
    check br.total == uHigh.to(FancyScalar)

    check br.le(uHigh) == iv(uHigh,uHigh)
    check br.le(uHigh-1) == iv(0,uHigh-2)
    check br.le(uHigh-2) == iv(0,uHigh-2)
    check br.le(uHigh-3) == ivError

    check br.ge(0) == iv(0,uHigh-2)
    check br.ge(1) == iv(uHigh,uHigh)
    check br.ge(uHigh-3) == iv(uHigh,uHigh)
    check br.ge(uHigh-2) == iv(uHigh,uHigh)
    check br.ge(uHigh-3) == iv(uHigh,uHigh)
    check br.ge(uHigh) == iv(uHigh,uHigh)

    check br.reduce(0,uHigh-2) == uHigh-1
    check br.verify.isOk
    check br.chunks == 1
    check br.total == 1.to(FancyScalar)

    check br.le(uHigh) == iv(uHigh,uHigh)
    check br.le(uHigh-1) == ivError
    check br.le(uHigh-2) == ivError
    check br.le(0) == ivError

    check br.ge(uHigh) == iv(uHigh,uHigh)
    check br.ge(uHigh-1) == iv(uHigh,uHigh)
    check br.ge(uHigh-2) == iv(uHigh,uHigh)
    check br.ge(0) == iv(uHigh,uHigh)

    br.clear()
    check br.total == 0 and br.chunks == 0
    check br.merge(0,uHigh) == 0
    check br.reduce(0,9999999) == 10000000
    check br.total.truncate(uint64) == (uHigh - 10000000) + 1
    check br.verify.isOk

    check br.merge(uHigh,uHigh) == 0
    check br.verify.isOk

    check br.reduce(uHigh,uHigh-1) == 1 # same as reduce(uHigh,uHigh)
    check br.total.truncate(uint64) == (uHigh - 10000000)
    check br.verify.isOk
    check br.merge(uHigh,uHigh-1) == 1 # same as merge(uHigh,uHigh)
    check br.total.truncate(uint64) == (uHigh - 10000000) + 1
    check br.verify.isOk

  test "More edge cases detected and fixed":
    br.clear()
    check br.total == 0 and br.chunks == 0
    check br.merge(uHigh,uHigh) == 1

    block:
      var (ivVal, ivSet) = (iv(0,0), false)
      for iv in br.increasing:
        check ivSet == false
        (ivVal, ivSet) = (iv, true)
      check ivVal == iv(uHigh,uHigh)
    block:
      var (ivVal, ivSet) = (iv(0,0), false)
      for iv in br.decreasing:
        check ivSet == false
        (ivVal, ivSet) = (iv, true)
      check ivVal == iv(uHigh,uHigh)

    br.clear() # from blockchain sync crash
    check br.total == 0 and br.chunks == 0
    check br.merge(1477152,uHigh) == uHigh - 1477151
    check br.merge(1477151,1477151) == 1

    br.clear() # from blockchain snap sync odd behaviour
    check br.merge(0,uHigh) == 0
    check br.ge(1000) == ivError
    check 0 < br.reduce(99999,uHigh-1)
    check br.ge(1000) == iv(uHigh,uHigh)

    br.clear()
    check br.merge(0,uHigh) == 0
    check br.le(uHigh) == iv(0,uHigh)
    check br.le(uHigh-1) == ivError
    check 0 < br.reduce(99999,uHigh-1)
    check br.le(uHigh) == iv(uHigh,uHigh)
    check br.le(uHigh-1) == iv(0,99998)
    check br.le(uHigh-2) == iv(0,99998)

  test "Interval envelopes":
    br.clear()
    check br.merge(0,uHigh) == 0
    check br.ge(1000) == ivError
    check br.le(1000) == ivError
    check br.envelope(1000) == iv(0,uHigh)

    check 0 < br.reduce(1000,1000)
    check br.envelope(1000) == ivError

    check 0 < br.reduce(uHigh,uHigh)
    check br.envelope(2000) == iv(1001,uHigh-1)
    check br.envelope(uHigh-1) == iv(1001,uHigh-1)

    check 0 < br.merge(0,uHigh) # actually == 2
    check 0 < br.reduce(uHigh-1,uHigh-1)
    check br.envelope(uHigh-1) == ivError
    check br.envelope(uHigh-2) == iv(0,uHigh-2)
    check br.ge(uHigh) == iv(uHigh,uHigh)
    check br.envelope(uHigh) == iv(uHigh,uHigh)

  test "Merge overlapping intervals":
    br.clear()
    check br.merge(100, 199) == 100
    check br.merge(150, 200) == 1
    check br.total == 101
    check br.chunks == 1
    check br.verify.isOk
    check br.merge( 99, 150) == 1
    check br.total == 102
    check br.chunks == 1
    check br.verify.isOk

  test "Merge disjunct intervals on 1st set":
    br.clear()
    check br.merge(  0,  99) == 100
    check br.merge(200, 299) == 100
    check br.merge(400, 499) == 100
    check br.merge(600, 699) == 100
    check br.merge(800, 899) == 100
    check br.total == 500
    check br.chunks == 5
    check br.verify.isOk

  test "Reduce non overlapping intervals on 1st set":
    check br.reduce(100, 199) == 0
    check br.reduce(300, 399) == 0
    check br.reduce(500, 599) == 0
    check br.reduce(700, 799) == 0
    check br.verify.isOk

  test "Clone a 2nd set and verify covered data ranges":
    dup = br.clone
    check dup.covered(  0,  99) == 100
    check dup.covered(100, 199) == 0
    check dup.covered(200, 299) == 100
    check dup.covered(300, 399) == 0
    check dup.covered(400, 499) == 100
    check dup.covered(500, 599) == 0
    check dup.covered(600, 699) == 100
    check dup.covered(700, 799) == 0
    check dup.covered(800, 899) == 100
    check dup.covered(900, uint64.high) == 0

    check dup.covered(200, 599) == 200
    check dup.covered(200, 799) == 300
    check dup.total == 500
    check dup.chunks == 5
    check dup.verify.isOk

  test "Merge overlapping intervals on 2nd set":
    check dup.merge( 50, 250) == 100
    check dup.merge(450, 850) == 200
    check dup.verify.isOk

  test "Verify covered data ranges on 2nd set":
    check dup.covered(  0, 299) == 300
    check dup.covered(300, 399) == 0
    check dup.covered(400, 899) == 500
    check dup.covered(900, uint64.high) == 0
    check dup.total == 800
    check dup.chunks == 2
    check dup.verify.isOk

  test "Verify 1st and 2nd set differ":
    check br != dup

  test "Reduce overlapping intervals on 2nd set":
    check dup.reduce(100, 199) == 100
    check dup.reduce(500, 599) == 100
    check dup.reduce(700, 799) == 100
    check dup.verify.isOk

  test "Verify 1st and 2nd set equal":
    check br == dup
    check br == br
    check dup == dup

  test "Find intervals in the 1st set":
    check br.le(100) == iv(  0,  99)
    check br.le(199) == iv(  0,  99)
    check br.le(200) == iv(  0,  99)
    check br.le(299) == iv(200, 299)
    check br.le(999) == iv(800, 899)
    check br.le(50) == ivError

    check br.ge(  0) == iv(  0,  99)
    check br.ge(  1) == iv(200, 299)
    check br.ge(800) == iv(800, 899)
    check br.ge(801) == ivError

  test "Delete intervals from the 2nd set":
    check dup.delete(200) == iv(200, 299)
    check dup.delete(800) == iv(800, 899)
    check dup.verify.isOk

  test "Interval intersections":
    check iv(100, 199) * iv(150, 249) == iv(150, 199)
    check iv(150, 249) * iv(100, 199) == iv(150, 199)

    check iv(100, 199) * iv(200, 299) == ivError
    check iv(200, 299) * iv(100, 199) == ivError

    check iv(200, uHigh) * iv(uHigh,uHigh) == iv(uHigh,uHigh)
    check iv(uHigh, uHigh) * iv(200,uHigh) == iv(uHigh,uHigh)

    check iv(100, 199) * iv(150, 249) * iv(100, 170) == iv(150, 170)
    check (iv(100, 199) * iv(150, 249)) * iv(100, 170) == iv(150, 170)
    check iv(100, 199) * (iv(150, 249) * iv(100, 170)) == iv(150, 170)

  test "Join intervals":
    check iv(100, 199) + iv(150, 249) == iv(100, 249)
    check iv(150, 249) + iv(100, 199) == iv(100, 249)

    check iv(100, 198) + iv(202, 299) == ivError
    check iv(100, 199) + iv(200, 299) == iv(100, 299)
    check iv(100, 200) + iv(200, 299) == iv(100, 299)
    check iv(100, 201) + iv(200, 299) == iv(100, 299)

    check iv(200, 299) + iv(100, 198) == ivError
    check iv(200, 299) + iv(100, 199) == iv(100, 299)
    check iv(200, 299) + iv(100, 200) == iv(100, 299)
    check iv(200, 299) + iv(100, 201) == iv(100, 299)

    check iv(200, uHigh) + iv(uHigh,uHigh) == iv(200,uHigh)
    check iv(uHigh, uHigh) + iv(200,uHigh) == iv(200,uHigh)

    check iv(150, 249) + iv(100, 149) + iv(200, 299) == iv(100, 299)
    check (iv(150, 249) + iv(100, 149)) + iv(200, 299) == iv(100, 299)
    check iv(150, 249) + (iv(100, 149) + iv(200, 299)) == ivError

  test "Cut off intervals by other intervals":
    check iv(100, 199) - iv(150, 249) == iv(100, 149)
    check iv(150, 249) - iv(100, 199) == iv(200, 249)
    check iv(100, 199) - iv(200, 299) == iv(100, 199)
    check iv(200, 299) - iv(100, 199) == iv(200, 299)

    check iv(200, 399) - iv(250, 349) == ivError
    check iv(200, 299) - iv(200, 299) == ivError
    check iv(200, 299) - iv(200, 399) == ivError
    check iv(200, 299) - iv(100, 299) == ivError
    check iv(200, 299) - iv(100, 399) == ivError

    check iv(200, 299) - iv(100, 199) - iv(150, 249) == iv(250, 299)
    check (iv(200, 299) - iv(100, 199)) - iv(150, 249) == iv(250, 299)
    check iv(200, 299) - (iv(100, 199) - iv(150, 249)) == iv(200, 299)

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------
