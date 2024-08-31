import ./evalonce

type ArrayBuf*[N: static int, T = byte] = object
  ## An fixed-capacity, allocation-free buffer with a seq-like API - suitable
  ## for keeping small amounts of data since the full capacity is reserved on
  ## instantiation (using an `array`).
  buf*: array[N, T]

  when N <= uint8.high:
    n*: uint8
  elif N <= uint16.high:
    n*: uint16
  elif N <= uint32.high:
    n*: uint32
  else:
    n*: int
      # Number of entries actually in use - uses the smallest unsigned integer
      # that can hold values up to the capacity to avoid wasting memory on
      # alignment and counting, specially when `T = byte` and odd sizes are used

template len*(b: ArrayBuf): int =
  int(b.n)

template setLen*(b: var ArrayBuf, newLenParam: int) =
  newLenParam.evalOnceAs(newLen)
  let
    nl = typeof(b.n)(newLen)
  for i in newLen ..< b.len():
    reset(b.buf[i])
  b.n = nl

template data*(bParam: ArrayBuf): openArray =
  bParam.evalOnceAs(b)
  b.buf.toOpenArray(0, b.len() - 1)

template data*(bParam: var ArrayBuf): var openArray =
  # Careful, double evaluation of b
  bParam.evalOnceAs(b)
  b.buf.toOpenArray(0, b.len() - 1)

iterator items*[N, T](b: ArrayBuf[N, T]): lent T =
  for i in 0 ..< b.len:
    yield b.d[i]

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

template `==`*(a, b: ArrayBuf): bool =
  a.data() == b.data()

template `<`*(a, b: ArrayBuf): bool =
  a.data() < b.data()

template add*[N, T](b: var ArrayBuf[N, T], v: T) =
  # Panics if too many items are added
  # TODO `b` is evaluated multiple times but since it's a `var` this should
  #      _hopefully_ be fine..
  b.buf[b.len] = v
  b.n += 1
