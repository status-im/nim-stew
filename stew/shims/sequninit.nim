# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) Status Research & Development GmbH

{.used.}

when not declared(newSeqUninit):
  # https://github.com/nim-lang/Nim/pull/22739
  # v2.0.0+
  template newSeqUninit*[T](len: Natural): seq[T] =
    when T is SomeNumber:
      newSeqUninitialized[T](len)
    else:
      newSeq[T](len)

when not declared(setLenUninit):
  # https://github.com/nim-lang/Nim/pull/22767
  # https://github.com/nim-lang/Nim/pull/25022
  # v2.0.6+ (orc), v2.2.8 (refc)

  template setLenUninit*(s: var seq, newlen: Natural) =
    s.setLen(newlen)
