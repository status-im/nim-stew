# stew
# Copyright 2024 Status Research & Development GmbH
# Licensed under either of
#
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)
#
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import ./[evalonce, arrayops]

type ArrayBuf*[N: static int, T] = object
  ## An fixed-capacity, allocation-free buffer with a seq-like API - suitable
  ## for keeping small amounts of data since the full capacity is reserved on
  ## instantiation (using an `array`).
  #
  # `N` must be "simple enough" or one of these will trigger
  # TODO https://github.com/nim-lang/Nim/issues/24043
  # TODO https://github.com/nim-lang/Nim/issues/24044
  # TODO https://github.com/nim-lang/Nim/issues/24045
  buf*: array[N, T]

  when sizeof(int) > sizeof(uint8):
    when N <= int(uint8.high):
      n*: uint8
    else:
      when sizeof(int) > sizeof(uint16):
        when N <= int(uint16.high):
          n*: uint16
        else:
          when sizeof(int) > sizeof(uint32):
            # TODO https://github.com/nim-lang/Nim/issues/24041
            when N <= cast[int](uint32.high):
              n*: uint32
            else:
              n*: int
          else:
            n*: int
      else:
        n*: int
  else:
    n*: int
      # Number of entries actually in use - uses the smallest unsigned integer
      # that can hold values up to the capacity to avoid wasting memory on
      # alignment and counting, specially when `T = byte` and odd sizes are used

template len*(b: ArrayBuf): int =
  int(b.n)

template setLen*(b: var ArrayBuf, newLenParam: int) =
  block:
    newLenParam.evalOnceAs(newLen)
    let nl = typeof(b.n)(newLen)
    for i in newLen ..< b.len():
      reset(b.buf[i]) # reset cleared items when shrinking
    b.n = nl

template data*(bParam: ArrayBuf): openArray =
  # TODO https://github.com/nim-lang/Nim/issues/24260
  # TODO https://github.com/nim-lang/Nim/issues/24261
  bParam.evalOnceAs(bArrayBufPrivate)
  bArrayBufPrivate.buf.toOpenArray(0, bArrayBufPrivate.len() - 1)

template data*(bParam: var ArrayBuf): var openArray =
  # TODO https://github.com/nim-lang/Nim/issues/24260
  # TODO https://github.com/nim-lang/Nim/issues/24261
  bParam.evalOnceAs(bArrayBufPrivate)
  bArrayBufPrivate.buf.toOpenArray(0, bArrayBufPrivate.len() - 1)

iterator items*[N, T](b: ArrayBuf[N, T]): lent T =
  for i in 0 ..< b.len:
    yield b.buf[i]

iterator mitems*[N, T](b: var ArrayBuf[N, T]): var T =
  for i in 0 ..< b.len:
    yield b.d[i]

iterator pairs*[N, T](b: ArrayBuf[N, T]): (int, lent T) =
  for i in 0 ..< b.len:
    yield (i, b.buf[i])

template `[]`*[N, T](b: ArrayBuf[N, T], i: int): lent T =
  b.buf[i]

template `[]`*[N, T](b: var ArrayBuf[N, T], i: int): var T =
  b.buf[i]

template `[]=`*[N, T](b: var ArrayBuf[N, T], i: int, v: T) =
  b.buf[i] = v

template `[]`*[N, T](b: ArrayBuf[N, T], i: BackwardsIndex): lent T =
  b.buf[b.len - int(i)]

template `==`*(a, b: ArrayBuf): bool =
  a.data() == b.data()

template `<`*(a, b: ArrayBuf): bool =
  a.data() < b.data()

template initCopyFrom*[N, T](
    _: type ArrayBuf[N, T], data: openArray[T]
): ArrayBuf[N, T] =
  var v: ArrayBuf[N, T]
  v.n = typeof(v.n)(v.buf.copyFrom(data))
  v

template initCopyFrom*[N, T](
    _: type ArrayBuf[N, T], data: array[N, T]
): ArrayBuf[N, T] =
  # Shortcut version that avoids zeroMem on matching lengths
  ArrayBuf[N, T](
    buf: data,
    n: N
  )

template add*[N, T](b: var ArrayBuf[N, T], v: T) =
  ## Adds items up to capacity then drops the rest
  # TODO `b` is evaluated multiple times but since it's a `var` this should
  #      _hopefully_ be fine..
  if b.len < N:
    b.buf[b.len] = v
    b.n += 1

template add*[N, T](b: var ArrayBuf[N, T], v: openArray[T]) =
  ## Adds items up to capacity then drops the rest
  # TODO `b` is evaluated multiple times but since it's a `var` this should
  #      _hopefully_ be fine..
  b.n += typeof(b.n)(b.buf.toOpenArray(b.len, N - 1).copyFrom(v))

template pop*[N, T](b: var ArrayBuf[N, T]): T =
  ## Return the last item while removing it from the buffer
  # TODO `b` is evaluated multiple times but since it's a `var` this should
  #      _hopefully_ be fine..
  assert b.n > 0, "pop from empty ArrayBuf"
  b.n -= 1
  move(b.buf[b.n])
