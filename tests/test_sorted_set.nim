# Nimbus
# Copyright (c) 2018-2022 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

{.used.}

import
  std/[algorithm, sequtils, strformat, sets, tables],
  ../stew/sorted_set,
  unittest2

const
  keyList = [
    185, 208,  53,  54, 196, 189, 187, 117,  94,  29,   6, 173, 207,  45,  31,
    208, 127, 106, 117,  49,  40, 171,   6,  94,  84,  60, 125,  87, 168, 183,
    200, 155,  34,  27,  67, 107, 108, 223, 249,   4, 113,   9, 205, 100,  77,
    224,  19, 196,  14,  83, 145, 154,  95,  56, 236,  97, 115, 140, 134,  97,
    153, 167,  23,  17, 182, 116, 253,  32, 108, 148, 135, 169, 178, 124, 147,
    231, 236, 174, 211, 247,  22, 118, 144, 224,  68, 124, 200,  92,  63, 183,
    56,  107,  45, 180, 113, 233,  59, 246,  29, 212, 172, 161, 183, 207, 189,
    56,  198, 130,  62,  28,  53, 122]

  numUniqeKeys = keyList.toHashSet.len
  numKeyDups = keyList.len - numUniqeKeys

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

iterator fwdItems(sl: var SortedSet[int,int]): int =
  var rc = sl.ge(0)
  while rc.isOk:
    yield rc.value.key
    rc = sl.gt(rc.value.key)

iterator revItems(sl: var SortedSet[int,int]): int =
  var rc = sl.le(int.high)
  while rc.isOk:
    yield rc.value.key
    rc = sl.lt(rc.value.key)

iterator fwdWalk(sl: var SortedSet[int,int]): int =
  var
    w = SortedSetWalkRef[int,int].init(sl)
    rc = w.first
  while rc.isOk:
    yield rc.value.key
    rc = w.next
  w.destroy

iterator revWalk(sl: var SortedSet[int,int]): int =
  var
    w = SortedSetWalkRef[int,int].init(sl)
  var
    rc = w.last
  while rc.isOk:
    yield rc.value.key
    rc = w.prev
  w.destroy

# ------------------------------------------------------------------------------
# Setup functions
# ------------------------------------------------------------------------------

proc insertKeyListItems(kl: openArray[int]): (SortedSet[int,int],seq[int]) =
  var
    sl = SortedSet[int,int].init
    rej: seq[int]

  for n in keyList:
    let rc = sl.insert(n)
    if rc.isErr:
      rej.add n
    else:
      rc.value.data = -n
    let check = sl.verify
    if check.isErr:
      check check.error[1] == rbOk # force message

  (sl,rej)

# ------------------------------------------------------------------------------
# Test Runners
# ------------------------------------------------------------------------------

proc sortedSetRunner(kl: openArray[int]) =
  suite "SortedSet: Sorted list based on red-black tree":
    setup:
      var (sl, rej) = keyList.insertKeyListItems

    test &"Insert {keyList.len} items, reject {numKeyDups} duplicates":
      check sl.len == numUniqeKeys
      check rej.len == numKeyDups
      check sl.len + rej.len == keyList.len

    test "Verify increasing/decreasing traversals":
      check toSeq(sl.fwdItems) == toSeq(sl.fwdWalk)
      check toSeq(sl.revItems) == toSeq(sl.revWalk)
      check toSeq(sl.fwdItems) == toSeq(sl.revWalk).reversed
      check toSeq(sl.revItems) == toSeq(sl.fwdWalk).reversed

      # check `sLstEq()`
      block:
        var rc = sl.ge(0)
        while rc.isOk:
          check rc == sl.eq(rc.value.key)
          rc = sl.gt(rc.value.key)

      # check `sLstThis()`
      block:
        var
          w = SortedSetWalkRef[int,int].init(sl)
          rc = w.first
        while rc.isOk:
          check rc == w.this
          rc = w.next
        w.destroy

    test "Delete items":
      var seen: seq[int]
      let sub7 = keyList.len div 7
      for n in toSeq(countup(0,sub7)).concat(toSeq(countup(3*sub7,4*sub7))):
        let
          key = keyList[n]
          canDeleteOk = (key notin seen)

          data = sl.delete(key)
          slCheck = sl.verify

        if key notin seen:
          seen.add key

        if slCheck.isErr:
          check slCheck.error[1] == rbOk # force message
        check data.isOk == canDeleteOk

        if data.isOk: # assuming data.isOk == canDeleteOk if correct
          check data.value.key == key

      check seen.len + sl.len + rej.len == keyList.len

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

keyList.sortedSetRunner

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------
