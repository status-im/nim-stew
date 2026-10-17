# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) Status Research & Development GmbH

{.push raises: [], gcsafe.}
{.used.}

# https://github.com/nim-lang/Nim/pull/24836
# https://github.com/nim-lang/Nim/pull/25022
# https://github.com/nim-lang/Nim/pull/25767
# can't properly override broken-but-extant setLenUninit with any of
# proc/func/template, so use setLenUninit2
# TODO if Nim 2.2.12 gets a 25767 backport, allow in refc
template setLenUninit2*(s: var string, newlen: Natural) =
  when (NimMajor, NimMinor, NimPatch) < (2, 2, 10) or
       ((NimMajor, NimMinor) < (2, 4) and defined(gcRefc)):
    setLen(s, newLen)
  else:
    setLenUninit(s, newLen)
