# Copyright (c) 2020-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

when (NimMajor, NimMinor) < (1, 4):
  {.push raises: [Defect].}
else:
  {.push raises: [].}

## Operations on array and openArray

import
  ./assign2

export assign2

template eachElement(x, res, op: untyped) =
  for i in 0..<res.len:
    res[i] = op(x[i])

template eachElement(x, y, res, op: untyped) =
  for i in 0..<res.len:
    res[i] = op(x[i], y[i])

func `and`*[N: static int; T](x, y: array[N, T]): array[N, T] =
  eachElement(x, y, result, `and`)

func `or`*[N: static int; T](x, y: array[N, T]): array[N, T] =
  eachElement(x, y, result, `or`)

func `xor`*[N: static int; T](x, y: array[N, T]): array[N, T] =
  eachElement(x, y, result, `xor`)

func `not`*[N: static int; T](x: array[N, T]): array[N, T] =
  eachElement(x, result, `not`)

func mand*[N: static int; T](x: var array[N, T], y: array[N, T]) =
  eachElement(x, y, x, `and`)

func mor*[N: static int; T](x: var array[N, T], y: array[N, T]) =
  eachElement(x, y, x, `or`)

func mxor*[N: static int; T](x: var array[N, T], y: array[N, T]) =
  eachElement(x, y, x, `xor`)

func mnot*[N: static int; T](x: var array[N, T], y: array[N, T]) =
  eachElement(x, x, `not`)

func copyFrom*[T](
    v: var openArray[T], src: openArray[T]): Natural =
  ## Copy `src` contents into `v` - this is a permissive assignment where `src`
  ## may contain both fewer and more elements than `v`. Returns the number of
  ## elements copied which may be less than N when `src` is shorter than v
  let elems = min(v.len, src.len)
  assign(v.toOpenArray(0, elems - 1), src.toOpenArray(0, elems - 1))
  elems

func initCopyFrom*[N: static[int], T](
    A: type array[N, T], src: openArray[T]): A =
  ## Copy `src` contents into an array - this is a permissive copy where `src`
  ## may contain both fewer and more elements than `N`.
  let elems = min(N, src.len)
  assign(result.toOpenArray(0, elems - 1), src.toOpenArray(0, elems - 1))

func initArrayWith*[N: static[int], T](value: T): array[N, T] {.noinit, inline.}=
  result.fill(value)

func `&`*[N1, N2: static[int], T](
    a: array[N1, T],
    b: array[N2, T]
    ): array[N1 + N2, T] {.inline, noinit.}=
  ## Array concatenation
  assign(result.toOpenArray(0, N1 - 1), a)
  assign(result.toOpenArray(N1, result.high), b)

template `^^`(s, i: untyped): untyped =
  (when i is BackwardsIndex: s.len - int(i) else: int(i))

func `[]=`*[T, U, V](r: var openArray[T], s: HSlice[U, V], v: openArray[T]) =
  ## openArray slice assignment:
  ## v[0..<2] = [0, 1]
  let a = r ^^ s.a
  let b = r ^^ s.b
  let L = b - a + 1
  if L == v.len:
    assign(r.toOpenArray(a, a + L - 1), v)
  else:
    raiseAssert "different lengths for slice assignment: " & $L & " vs " & $v
