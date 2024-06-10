# Nimbus
# Copyright (c) 2018-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

## Keyed Queue
## ===========
##
## This module provides a keyed fifo or stack data structure similar to
## `DoublyLinkedList` but with efficient random data access for fetching
## and deletion. The underlying data structure is a hash table with data
## lookup and delete assumed to be O(1) in most cases (so long as the
## underlying hash table does not degrade into one-bucket linear mode, or
## some bucket-adjustment algorithm takes over.)
##
## For consistency with  other data types in Nim the queue has value
## semantics, this means that `=` performs a deep copy of the allocated queue
## which is refered to the deep copy semantics of the underlying table driver.

import std/tables, results

export results

{.push raises: [].}

type
  KeyedQueueItem*[K, V] = object
    ## Data value container as stored in the queue.
    ## There is a special requirements for `KeyedQueueItem` terminal nodes:
    ## *prv == nxt* so that there is no dangling link. On the flip side,
    ## this requires some extra consideration when deleting the second node
    ## relative to either end.
    data*: V         ## Some data value, can freely be modified.
    kPrv*, kNxt*: K  ## Queue links, read-only.

  KeyedQueuePair*[K, V] = object ## Key-value pair, typically used as return code.
    key: K      ## Sorter key (read-only for consistency with `SLstResult[K,V]`)
    data*: V    ## Some data value, to be modified freely

  KeyedQueueTab*[K, V] = Table[K, KeyedQueueItem[K, V]]
    ## Internal table type exposed for debugging.

  KeyedQueue*[K, V] = object ## Data queue descriptor
    tab*: KeyedQueueTab[K, V]   ## Data table
    kFirst*, kLast*: K          ## Doubly linked item list queue

  BlindValue = distinct tuple[] ## Type name is syntactic sugar, used for key-only queues

  KeyedQueueNV*[K] = KeyedQueue[K, BlindValue] ## Key-only queue, no values

# ------------------------------------------------------------------------------
# Private helpers
# ------------------------------------------------------------------------------

template noKeyError(info: static[string], code: untyped) =
  try:
    code
  except KeyError as e:
    raiseAssert "Not possible (" & info & "): " & e.msg

# ------------------------------------------------------------------------------
# Private functions
# ------------------------------------------------------------------------------

proc shiftImpl[K, V](rq: var KeyedQueue[K, V]) =
  ## Expects: rq.tab.len != 0
  assert rq.tab.len != 0 # debugging only

  let first = rq.kFirst
  rq.tab.withValue(first, item):
    if rq.tab.len == 1: # item only
      rq.kFirst.reset
      rq.kLast.reset
    else:
      rq.tab.withValue(item[].kNxt, next):
        if rq.tab.len == 2: # item and one more
          next[].kNxt = item[].kNxt # node points to itself
        next[].kPrv = next[].kNxt # term nd has: nxt == prv
      rq.kFirst = item[].kNxt
  do:
    raiseAssert "rq.kFirst missing"

  rq.tab.del(first)

proc popImpl[K, V](rq: var KeyedQueue[K, V]) =
  ## Expects: rq.tab.len != 0

  # Pop last item
  let last = rq.kLast
  rq.tab.withValue(last, item):
    if rq.tab.len == 1: # item only
      rq.kFirst.reset
      rq.kLast.reset
    else:
      rq.tab.withValue(item[].kPrv, prev):
        if rq.tab.len == 2: # item and one more
          prev[].kPrv = item[].kPrv # single node points to itself
        prev[].kNxt = prev[].kPrv # term node has: nxt == prv
      rq.kLast = item[].kPrv
  do:
    raiseAssert "rq.kLast missing"

  rq.tab.del(last)

proc deleteImpl[K, V](rq: var KeyedQueue[K, V], key: K) =
  ## Expects: rq.tab.hesKey(key)

  if rq.kFirst == key:
    rq.shiftImpl
  elif rq.kLast == key:
    rq.popImpl
  else:
    rq.tab.withValue(key, item):
      # now: 2 < rq.tab.len (otherwise rq.kFirst == key or rq.kLast == key)
      rq.tab.withValue(rq.kFirst, first):
        if first[].kNxt == key:
          # item was the second one
          first[].kPrv = item[].kNxt
      rq.tab.withValue(rq.kLast, last):
        if last.kPrv == key:
          # item was one before last
          last.kNxt = item[].kPrv

      rq.tab.withValue(item[].kPrv, other):
        other[].kNxt = item[].kNxt
      rq.tab.withValue(item[].kNxt, other):
        other[].kPrv = item[].kPrv
    do:
      raiseAssert "item missing"

    rq.tab.del(key)

proc appendImpl[K, V](rq: var KeyedQueue[K, V], key: K, val: sink V) =
  ## Expects: not rq.tab.hasKey(key)

  # Append queue item
  var item = KeyedQueueItem[K, V](data: move(val))
  if rq.tab.len == 0:
    rq.kFirst = key
    item.kPrv = key
  else:
    if rq.kFirst == rq.kLast:
      rq.tab.withValue(rq.kFirst, first):
        first[].kPrv = key
        first[].kNxt = key
    else:
      rq.tab.withValue(rq.kLast, last):
        last[].kNxt = key

    item.kPrv = rq.kLast

  rq.kLast = key
  item.kNxt = item.kPrv # terminal node

  rq.tab[key] = move(item)

proc prependImpl[K, V](rq: var KeyedQueue[K, V], key: K, val: sink V) =
  ## Expects: not rq.tab.hasKey(key)

  # Prepend queue item
  var item = KeyedQueueItem[K, V](data: move(val))

  if rq.tab.len == 0:
    rq.kLast = key
    item.kNxt = key
  else:
    if rq.kFirst == rq.kLast:
      rq.tab.withValue(rq.kLast, last):
        last[].kNxt = key
        last[].kPrv = key
    else:
      rq.tab.withValue(rq.kFirst, first):
        first[].kPrv = key

    item.kNxt = rq.kFirst

  rq.kFirst = key
  item.kPrv = item.kNxt # terminal node has: nxt == prv

  rq.tab[key] = move(item)

# -----------

proc shiftKeyImpl[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  if 0 < rq.tab.len:
    let key = rq.kFirst
    rq.shiftImpl
    Opt.some(key)
  else:
    Opt.none(K)

proc popKeyImpl[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  if 0 < rq.tab.len:
    let key = rq.kLast
    rq.popImpl
    Opt.some(key)
  else:
    Opt.none(K)

# -----------

proc firstKeyImpl[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  if rq.tab.len == 0:
    Opt.none(K)
  else:
    Opt.some(rq.kFirst)

proc secondKeyImpl[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  if rq.tab.len < 2:
    return Opt.none(K)
  noKeyError("secondKeyImpl"):
    return Opt.some(rq.tab[rq.kFirst].kNxt)

proc beforeLastKeyImpl[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  if rq.tab.len < 2:
    return Opt.none(K)
  noKeyError("lastKeyImpl"):
    return Opt.some(rq.tab[rq.kLast].kPrv)

proc lastKeyImpl[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  if rq.tab.len == 0:
    Opt.none(K)
  else:
    Opt.some(rq.kLast)

proc nextKeyImpl[K, V](rq: var KeyedQueue[K, V], key: K): Opt[K] =
  if not rq.tab.hasKey(key) or rq.kLast == key:
    return Opt.none(K)
  noKeyError("nextKeyImpl"):
    return Opt.some(rq.tab[key].kNxt)

proc prevKeyImpl[K, V](rq: var KeyedQueue[K, V], key: K): Opt[K] =
  if not rq.tab.hasKey(key) or rq.kFirst == key:
    return Opt.none(K)
  noKeyError("prevKeyImpl"):
    return Opt.some(rq.tab[key].kPrv)

# ------------------------------------------------------------------------------
# Public functions, constructor
# ------------------------------------------------------------------------------

proc init*[K, V](rq: var KeyedQueue[K, V], initSize = defaultInitialSize) =
  ## Optional initaliser for the queue setting the inital size of the
  ## underlying table object.
  rq.tab = initTable[K, KeyedQueueItem[K, V]](initSize)

proc init*[K, V](T: type KeyedQueue[K, V], initSize = defaultInitialSize): T =
  ## Initaliser variant.
  result.init(initSize)

proc init*[K](rq: var KeyedQueueNV[K], initSize = defaultInitialSize) =
  ## Key-only queue, no explicit values
  rq.tab = initTable[K, KeyedQueueItem[K, BlindValue]](initSize)

proc init*[K](T: type KeyedQueueNV[K], initSize = defaultInitialSize): T =
  ## Initaliser variant.
  result.init(initSize)

# ------------------------------------------------------------------------------
# Public functions, list operations
# ------------------------------------------------------------------------------

proc append*[K, V](rq: var KeyedQueue[K, V], key: K, val: V): bool =
  ## Append new `key`. The function will succeed returning `true` unless the
  ## `key` argument exists in the queue,  already.
  ##
  ## All the items on the queue different from the one just added are
  ## called *previous* or *left hand* items while the item just added
  ## is the *right-most* item.
  rq.tab.withValue(key, item):
    return false
  do:
    rq.appendImpl(key, val)
    return true

template push*[K, V](rq: var KeyedQueue[K, V], key: K, val: V): bool =
  ## Same as `append()`
  rq.append(key, val)

proc replace*[K, V](rq: var KeyedQueue[K, V], key: K, val: V): bool =
  ## Replace value for entry associated with the key argument `key`. Returns
  ## `true` on success, and `false` otherwise.
  rq.tab.withValue(key, item):
    item[].data = val
    return true
  do:
    return false

proc `[]=`*[K, V](rq: var KeyedQueue[K, V], key: K, val: V) =
  ## This function provides a combined append/replace action with table
  ## semantics:
  ## * If the argument `key` is not in the queue yet, append the `(key,val)`
  ##   pair as in `rq.append(key,val)`
  ## * Otherwise replace the value entry of the queue item by the argument
  ##   `val` as in `rq.replace(key,val)`
  rq.tab.withValue(key, item):
    item[].data = val
  do:
    rq.appendImpl(key, val)

proc prepend*[K, V](rq: var KeyedQueue[K, V], key: K, val: V): bool =
  ## Prepend new `key`. The function will succeed returning `true` unless the
  ## `key` argument exists in the queue, already.
  ##
  ## All the items on the queue different from the item just added are
  ## called *following* or *right hand* items while the item just added
  ## is the *left-most* item.
  rq.tab.withValue(key, item):
    return false
  do:
    rq.prependImpl(key, val)
    return true

template unshift*[K, V](rq: var KeyedQueue[K, V], key: K, val: V): bool =
  ## Same as `prepend()`
  rq.prepend(key, val)

proc shift*[K, V](rq: var KeyedQueue[K, V]): Opt[KeyedQueuePair[K, V]] =
  ## Deletes the *first* queue item and returns the key-value item pair just
  ## deleted. For a non-empty queue this function is the same as
  ## `rq.firstKey.value.delele`.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## item returned and deleted is the *left-most* item.
  type T = KeyedQueuePair[K, V]
  if 0 < rq.tab.len:
    rq.tab.withValue(rq.kFirst, item):
      let res = Opt.some KeyedQueuePair[K, V](key: rq.kFirst, data: move(item[].data))
      rq.shiftImpl
      return res
  Opt.none(KeyedQueuePair[K, V])

proc shiftKey*[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  ## Similar to `shift()` but with different return value.
  rq.shiftKeyImpl

proc shiftValue*[K, V](rq: var KeyedQueue[K, V]): Opt[V] =
  ## Similar to `shift()` but with different return value.
  if 0 < rq.tab.len:
    rq.tab.withValue(rq.kFirst, item):
      let res = Opt.some(move(item[].data))
      rq.shiftImpl
      return res
  Opt.none(V)

proc pop*[K, V](rq: var KeyedQueue[K, V]): Opt[KeyedQueuePair[K, V]] =
  ## Deletes the *last* queue item and returns the  key-value item pair just
  ## deleted. For a non-empty queue this function is the same as
  ## `rq.lastKey.value.delele`.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## item returned and deleted is the *right-most* item.
  type T = KeyedQueuePair[K, V]
  if 0 < rq.tab.len:
    rq.tab.withValue(rq.kLast, item):
      let res = Opt.some T(key: rq.kLast, data: move(item[].data))
      rq.popImpl
      return res
  Opt.none(T)

proc popKey*[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  ## Similar to `pop()` but with different return value.
  rq.popKeyImpl

proc popValue*[K, V](rq: var KeyedQueue[K, V]): Opt[V] =
  ## Similar to `pop()` but with different return value.
  if 0 < rq.tab.len:
    rq.tab.withValue(rq.kLast, item):
      let res = Opt.some move(item[].data)
      rq.popImpl
      return res
  Opt.none(V)

proc delete*[K, V](rq: var KeyedQueue[K, V], key: K): Opt[KeyedQueuePair[K, V]] =
  ## Delete the item with key `key` from the queue and returns the key-value
  ## item pair just deleted (if any).
  type T = KeyedQueuePair[K, V]
  rq.tab.withValue(key, item):
    let res = Opt.some T(key: key, data: move(item[].data))
    rq.deleteImpl(key)
    return res

  Opt.none(T)

proc del*[K, V](rq: var KeyedQueue[K, V], key: K) =
  ## Similar to `delete()` but without return code.
  if rq.tab.hasKey(key):
    rq.deleteImpl(key)

# --------

proc append*[K](rq: var KeyedQueueNV[K], key: K): bool =
  ## Key-only queue variant
  rq.append(key, default(BlindValue))

template push*[K](rq: var KeyedQueueNV[K], key: K): bool =
  ## Key-only queue variant
  rq.append(key)

proc prepend*[K](rq: var KeyedQueueNV[K], key: K): bool =
  ## Key-only queue variant
  rq.prepend(key, default(BlindValue))

template unshift*[K](rq: var KeyedQueueNV[K], key: K): bool =
  ## Key-only queue variant
  rq.prepend(key)

proc shift*[K](rq: var KeyedQueueNV[K]): Opt[K] =
  ## Key-only queue variant
  rq.shiftKeyImpl

proc pop*[K](rq: var KeyedQueueNV[K]): Opt[K] =
  ## Key-only variant of `pop()` (same as `popKey()`)
  rq.popKeyImpl

# ------------------------------------------------------------------------------
# Public functions, fetch
# ------------------------------------------------------------------------------

proc hasKey*[K, V](rq: var KeyedQueue[K, V], key: K): bool =
  ## Check whether the argument `key` has been queued, already
  rq.tab.hasKey(key)

proc eq*[K, V](rq: var KeyedQueue[K, V], key: K): Opt[V] =
  ## Retrieve the value data stored with the argument `key` from
  ## the queue if there is any.
  if not rq.tab.hasKey(key):
    return Opt.none(V)
  noKeyError("eq"):
    return Opt.some(rq.tab[key].data)

proc `[]`*[K, V](rq: var KeyedQueue[K, V], key: K): var V {.raises: [KeyError].} =
  ## This function provides a simplified version of the `eq()` function with
  ## table semantics. Note that this finction throws a `KeyError` exception
  ## unless the argument `key` exists in the queue.
  rq.tab[key].data

# ------------------------------------------------------------------------------
# Public functions, LRU mode
# ------------------------------------------------------------------------------

proc lruFetch*[K, V](rq: var KeyedQueue[K, V], key: K): Opt[V] =
  ## Fetch in *last-recently-used* mode: If the argument `key` exists in the
  ## queue, move the key-value item pair to the *right end* (see `append()`)
  ## of the queue and return the value associated with the key.
  rq.tab.withValue(key, item):
    if rq.kLast != key:
      # Now, `key` is in the table and does not refer to the last `item`,
      # so the table has at least two entries.

      # unlink item
      if rq.kFirst == key:
        rq.kFirst = item[].kNxt
        rq.tab.withValue(rq.kFirst, first):
          first[].kPrv = first[].kNxt # term node: nxt == prv
      else: # Now, there are at least three entries
        rq.tab.withValue(rq.kFirst, first):
          if first[].kNxt == key:
            first[].kPrv = item[].kNxt # item was the 2nd one
        rq.tab.withValue(item[].kPrv, prev):
          prev[].kNxt = item[].kNxt
        rq.tab.withValue(item[].kNxt, next):
          next[].kPrv = item[].kPrv

      # Re-append item, i.e. appendImpl() without adding item.
      rq.tab.withValue(rq.kLast, last):
        last[].kNxt = key

      item[].kPrv = rq.kLast
      rq.kLast = key
      item[].kNxt = item[].kPrv # term node: nxt == prv
    return Opt.some(item[].data)

proc lruUpdate*[K, V](rq: var KeyedQueue[K, V], key: K, val: V): bool =
  ## Similar to `lruFetch()` with the difference that the item value is
  ## updated (i.e. set to `val`) if it is found on the queue. In that case,
  ## `true` is returned.
  ##
  ## Otherwise `false` is returned.
  ##
  rq.tab.withValue(key, w):
    w.data = val
    discard rq.lruFetch key
    return true

proc lruAppend*[K, V](rq: var KeyedQueue[K, V], key: K, val: V, maxItems: int): V =
  ## Append in *last-recently-used* mode: If the queue has at least `maxItems`
  ## item entries, do `shift()` out the *left-most* one. Then `append()` the
  ## key-value argument pair `(key,val)` to the *right end*. Together with
  ## `lruFetch()` (or `lruUpdate()`) this function can be used to implement
  ## an *LRU cache*.
  ##
  ## Example:
  ## ::
  ##   const queueMax = 10
  ##
  ##   proc expensiveCalculation(key: int): Result[int,void] =
  ##     ...
  ##
  ##   proc lruCache(q: var KeyedQueue[int,int]; key: int): Result[int,void] =
  ##     block:
  ##       let rc = q.lruFetch(key)
  ##       if rc.isOK:
  ##          return Opt.some(rc.value)
  ##     block:
  ##       let rc = expensiveCalculation(key)
  ##       if rc.isOK:
  ##          return Opt.some(q.lruAppend(key, rc.value, queueMax))
  ##     Opt.none(K)
  ##
  ## Caveat:
  ##   This fuction must always be used in combination with `lruFetch()` or
  ##   `lruUpdate()` while making sure that there exists no key `key` on the
  ##   queue. This function might throw an exception if this is violated.
  ##
  # Make sure that there is no such key. Otherwise the optimised `appendImpl()`
  # function might garble the list of links.
  doAssert not rq.tab.hasKey key

  # Limit number of cached items
  try:
    if maxItems <= rq.tab.len:
      rq.shiftImpl
    # Append new value
    rq.appendImpl(key, val)
    return val
  except KeyError:
    raiseAssert "Not possible"

# ------------------------------------------------------------------------------
# Public traversal functions, fetch keys
# ------------------------------------------------------------------------------

proc firstKey*[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  ## Retrieve first key from the queue unless it is empty.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## key returned is the *left-most* one.
  rq.firstKeyImpl

proc secondKey*[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  ## Retrieve the key next after the first key from queue unless it is empty.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## key returned is the one ti the right of the *left-most* one.
  rq.secondKeyImpl

proc beforeLastKey*[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  ## Retrieve the key just before the last one from queue unless it is empty.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## key returned is the one to the left of the *right-most* one.
  rq.beforeLastKeyImpl

proc lastKey*[K, V](rq: var KeyedQueue[K, V]): Opt[K] =
  ## Retrieve last key from queue unless it is empty.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## key returned is the *right-most* one.
  rq.lastKeyImpl

proc nextKey*[K, V](rq: var KeyedQueue[K, V], key: K): Opt[K] =
  ## Retrieve the key following the argument `key` from queue if
  ## there is any.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## key returned is the next one to the *right*.
  rq.nextKeyImpl(key)

proc prevKey*[K, V](rq: var KeyedQueue[K, V], key: K): Opt[K] =
  ## Retrieve the key preceeding the argument `key` from queue if
  ## there is any.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## key returned is the next one to the *left*.
  rq.prevKeyImpl(key)

# ----------

proc firstKey*[K](
    rq: var KeyedQueueNV[K]
): Opt[K] {.gcsafe, deprecated: "use first() for key-only queue".} =
  rq.firstKeyImpl

proc secondKey*[K](
    rq: var KeyedQueueNV[K]
): Opt[K] {.gcsafe, deprecated: "use second() for key-only queue".} =
  rq.secondKeyImpl

proc beforeLastKey*[K](
    rq: var KeyedQueueNV[K]
): Opt[K] {.gcsafe, deprecated: "use beforeLast() for key-only queue".} =
  rq.beforeLastKeyImpl

proc lastKey*[K](
    rq: var KeyedQueueNV[K]
): Opt[K] {.gcsafe, deprecated: "use last() for key-only queue".} =
  rq.lastKeyImpl

proc nextKey*[K](
    rq: var KeyedQueueNV[K], key: K
): Opt[K] {.gcsafe, deprecated: "use next() for key-only queue".} =
  rq.nextKeyImpl(key)

proc prevKey*[K](
    rq: var KeyedQueueNV[K], key: K
): Opt[K] {.gcsafe, deprecated: "use prev() for key-only queue".} =
  rq.nextKeyImpl(key)

# ------------------------------------------------------------------------------
# Public traversal functions, fetch key/value pairs
# ------------------------------------------------------------------------------

proc first*[K, V](rq: var KeyedQueue[K, V]): Opt[KeyedQueuePair[K, V]] =
  ## Similar to `firstKey()` but with key-value item pair return value.
  if rq.tab.len == 0:
    return Opt.none(KeyedQueuePair[K, V])
  noKeyError("first"):
    let key = rq.kFirst
    return Opt.some(KeyedQueuePair[K, V](key: key, data: rq.tab[key].data))

proc second*[K, V](rq: var KeyedQueue[K, V]): Opt[KeyedQueuePair[K, V]] =
  ## Similar to `secondKey()` but with key-value item pair return value.
  if rq.tab.len < 2:
    return Opt.none(KeyedQueuePair[K, V])
  noKeyError("second"):
    let key = rq.tab[rq.kFirst].kNxt
    return Opt.some(KeyedQueuePair[K, V](key: key, data: rq.tab[key].data))

proc beforeLast*[K, V](rq: var KeyedQueue[K, V]): Opt[KeyedQueuePair[K, V]] =
  ## Similar to `beforeLastKey()` but with key-value item pair return value.
  if rq.tab.len < 2:
    return Opt.none(KeyedQueuePair[K, V])
  noKeyError("beforeLast"):
    let key = rq.tab[rq.kLast].kPrv
    return Opt.some(KeyedQueuePair[K, V](key: key, data: rq.tab[key].data))

proc last*[K, V](rq: var KeyedQueue[K, V]): Opt[KeyedQueuePair[K, V]] =
  ## Similar to `lastKey()` but with key-value item pair return value.
  if rq.tab.len == 0:
    return Opt.none(KeyedQueuePair[K, V])
  noKeyError("last"):
    let key = rq.kLast
    return Opt.some(KeyedQueuePair[K, V](key: key, data: rq.tab[key].data))

proc next*[K, V](rq: var KeyedQueue[K, V], key: K): Opt[KeyedQueuePair[K, V]] =
  ## Similar to `nextKey()` but with key-value item pair return value.
  if not rq.tab.hasKey(key) or rq.kLast == key:
    return Opt.none(KeyedQueuePair[K, V])
  noKeyError("next"):
    let nKey = rq.tab[key].kNxt
    return Opt.some(KeyedQueuePair[K, V](key: nKey, data: rq.tab[nKey].data))

proc prev*[K, V](rq: var KeyedQueue[K, V], key: K): Opt[KeyedQueuePair[K, V]] =
  ## Similar to `prevKey()` but with key-value item pair return value.
  if not rq.tab.hasKey(key) or rq.kFirst == key:
    return Opt.none(KeyedQueuePair[K, V])
  noKeyError("prev"):
    let pKey = rq.tab[key].kPrv
    return Opt.some(KeyedQueuePair[K, V](key: pKey, data: rq.tab[pKey].data))

# ------------

proc first*[K](rq: var KeyedQueueNV[K]): Opt[K] =
  ## Key-only queue variant
  rq.firstKeyImpl

proc second*[K](rq: var KeyedQueueNV[K]): Opt[K] =
  ## Key-only queue variant
  rq.secondKeyImpl

proc beforeLast*[K](rq: var KeyedQueueNV[K]): Opt[K] =
  ## Key-only queue variant
  rq.beforeLastKeyImpl

proc last*[K](rq: var KeyedQueueNV[K]): Opt[K] =
  ## Key-only queue variant
  rq.lastKeyImpl

proc next*[K](rq: var KeyedQueueNV[K], key: K): Opt[K] =
  ## Key-only queue variant
  rq.nextKeyImpl(key)

proc prev*[K](rq: var KeyedQueueNV[K], key: K): Opt[K] =
  ## Key-only queue variant
  rq.nextKeyImpl(key)

# ------------------------------------------------------------------------------
# Public traversal functions, data container items
# ------------------------------------------------------------------------------

proc firstValue*[K, V](rq: var KeyedQueue[K, V]): Opt[V] =
  ## Retrieve first value item from the queue unless it is empty.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## value item returned is the *left-most* one.
  if rq.tab.len == 0:
    return Opt.none(V)
  noKeyError("firstValue"):
    return Opt.some(rq.tab[rq.kFirst].data)

proc secondValue*[K, V](rq: var KeyedQueue[K, V]): Opt[V] =
  ## Retrieve the value item next to the first one from the queue unless it
  ## is empty.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## value item returned is the one to the *right* of the *left-most* one.
  if rq.tab.len < 2:
    return Opt.none(K)
  noKeyError("secondValue"):
    return Opt.some(rq.tab[rq.tab[rq.kFirst].kNxt].data)

proc beforeLastValue*[K, V](rq: var KeyedQueue[K, V]): Opt[V] =
  ## Retrieve the value item just before the last item from the queue
  ## unless it is empty.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## value item returned is the one to the *left* of the *right-most* one.
  if rq.tab.len < 2:
    return Opt.none(V)
  noKeyError("beforeLastValue"):
    return Opt.some(rq.tab[rq.tab[rq.kLast].kPrv].data)

proc lastValue*[K, V](rq: var KeyedQueue[K, V]): Opt[V] =
  ## Retrieve the last value item from the queue if there is any.
  ##
  ## Using the notation introduced with `rq.append` and `rq.prepend`, the
  ## value item returned is the *right-most* one.
  if rq.tab.len == 0:
    return Opt.none(V)
  noKeyError("lastValue"):
    return Opt.some(rq.tab[rq.kLast].data)

# ------------------------------------------------------------------------------
# Public functions, miscellaneous
# ------------------------------------------------------------------------------

proc `==`*[K, V](a, b: var KeyedQueue[K, V]): bool =
  ## Returns `true` if both argument queues contain the same data. Note that
  ## this is a slow operation as all `(key,data)` pairs will to be compared.
  if a.tab.len == b.tab.len and a.kFirst == b.kFirst and a.kLast == b.kLast:
    for (k, av) in a.tab.pairs:
      if not b.tab.hasKey(k):
        return false
      noKeyError("=="):
        let bv = b.tab[k]
        # bv.data might be a reference, so dive into it explicitely.
        if av.kPrv != bv.kPrv or av.kNxt != bv.kNxt or bv.data != av.data:
          return false
    return true

proc key*[K, V](kqp: KeyedQueuePair[K, V]): K =
  ## Getter
  kqp.key

proc len*[K, V](rq: var KeyedQueue[K, V]): int =
  ## Returns the number of items in the queue
  rq.tab.len

proc clear*[K, V](rq: var KeyedQueue[K, V]) =
  ## Clear the queue
  rq.tab.clear
  rq.kFirst.reset
  rq.kLast.reset

proc toKeyedQueueResult*[K, V](key: K, data: V): Opt[KeyedQueuePair[K, V]] =
  ## Helper, chreate `Opt.some()` result
  Opt.some(KeyedQueuePair[K, V](key: key, data: data))

# ------------------------------------------------------------------------------
# Public iterators
# ------------------------------------------------------------------------------

iterator nextKeys*[K, V](rq: var KeyedQueue[K, V]): K =
  ## Iterate over all keys in the queue starting with the `rq.firstKey.value`
  ## key (if any). Using the notation introduced with `rq.append` and
  ## `rq.prepend`, the iterator processes *left* to *right*.
  ##
  ## :Note:
  ##    When running in a loop it is *ok* to delete the current item and all
  ##    the items already visited. Items not visited yet must not be deleted
  ##    as the loop would become unpredictable.
  if 0 < rq.tab.len:
    var
      key = rq.kFirst
      loopOK = true
    while loopOK:
      let yKey = key
      loopOK = key != rq.kLast
      noKeyError("nextKeys"):
        key = rq.tab[key].kNxt
      yield yKey

iterator nextValues*[K, V](rq: var KeyedQueue[K, V]): V =
  ## Iterate over all values in the queue starting with the
  ## `rq.kFirst.value.value` item value (if any). Using the notation introduced
  ## with `rq.append` and `rq.prepend`, the iterator processes *left* to
  ## *right*.
  ##
  ## See the note at the `nextKeys()` function comment about deleting items.
  if 0 < rq.tab.len:
    var
      key = rq.kFirst
      loopOK = true
    while loopOK:
      var item: KeyedQueueItem[K, V]
      noKeyError("nextValues"):
        item = rq.tab[key]
      loopOK = key != rq.kLast
      key = item.kNxt
      yield item.data

iterator nextPairs*[K, V](rq: var KeyedQueue[K, V]): KeyedQueuePair[K, V] =
  ## Iterate over all (key,value) pairs in the queue starting with the
  ## `(rq.firstKey.value,rq.first.value.value)` key/item pair (if any). Using
  ## the notation introduced with `rq.append` and `rq.prepend`, the iterator
  ## processes *left* to *right*.
  ##
  ## See the note at the `nextKeys()` function comment about deleting items.
  if 0 < rq.tab.len:
    var
      key = rq.kFirst
      loopOK = true
    while loopOK:
      let yKey = key
      var item: KeyedQueueItem[K, V]
      noKeyError("nextPairs"):
        item = rq.tab[key]
      loopOK = key != rq.kLast
      key = item.kNxt
      yield KeyedQueuePair[K, V](key: yKey, data: item.data)

iterator prevKeys*[K, V](rq: var KeyedQueue[K, V]): K =
  ## Reverse iterate over all keys in the queue starting with the
  ## `rq.lastKey.value` key (if any). Using the notation introduced with
  ## `rq.append` and `rq.prepend`, the iterator processes *right* to *left*.
  ##
  ## See the note at the `nextKeys()` function comment about deleting items.
  if 0 < rq.tab.len:
    var
      key = rq.kLast
      loopOK = true
    while loopOK:
      let yKey = key
      loopOK = key != rq.kFirst
      noKeyError("prevKeys"):
        key = rq.tab[key].kPrv
      yield yKey

iterator prevValues*[K, V](rq: var KeyedQueue[K, V]): V =
  ## Reverse iterate over all values in the queue starting with the
  ## `rq.kLast.value.value` item value (if any). Using the notation introduced
  ## with `rq.append` and `rq.prepend`, the iterator processes *right* to
  ## *left*.
  ##
  ## See the note at the `nextKeys()` function comment about deleting items.
  if 0 < rq.tab.len:
    var
      key = rq.kLast
      loopOK = true
    while loopOK:
      var item: KeyedQueueItem[K, V]
      noKeyError("prevValues"):
        item = rq.tab[key]
      loopOK = key != rq.kFirst
      key = item.kPrv
      yield item.data

iterator prevPairs*[K, V](rq: var KeyedQueue[K, V]): KeyedQueuePair[K, V] =
  ## Reverse iterate over all (key,value) pairs in the queue starting with the
  ## `(rq.lastKey.value,rq.last.value.value)` key/item pair (if any). Using
  ## the notation introduced with `rq.append` and `rq.prepend`, the iterator
  ## processes *right* to *left*.
  ##
  ## See the note at the `nextKeys()` function comment about deleting items.
  if 0 < rq.tab.len:
    var
      key = rq.kLast
      loopOK = true
    while loopOK:
      let yKey = key
      var item: KeyedQueueItem[K, V]
      noKeyError("prevPairs"):
        item = rq.tab[key]
      loopOK = key != rq.kFirst
      key = item.kPrv
      yield KeyedQueuePair[K, V](key: yKey, data: item.data)

# ------------------------------------------------------------------------------
# End
# ------------------------------------------------------------------------------
