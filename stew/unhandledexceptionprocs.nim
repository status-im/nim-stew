# This file is very similar to `exitprocs.nim` from this PR:
# https://github.com/nim-lang/Nim/pull/14342/files

import locks

type
  FunKind = enum kClosure, kNoconv # extend as needed
  Fun = object
    case kind: FunKind
    of kClosure: fun1: proc (e: ref Exception)
        {.closure, gcsafe, tags: [], raises: [], locks: 0.}
    of kNoconv: fun2: proc (e: ref Exception)
        {.noconv, gcsafe, tags: [], raises: [], locks: 0.}

var
  gFunsLock: Lock
  gFuns: seq[Fun]
  gFunsPtr: ptr seq[Fun]

initLock(gFunsLock)

proc callClosures(e: ref Exception)
  {.nimcall, gcsafe, tags: [], raises: [], locks: 0.} =
  withLock gFunsLock:
    for i in countdown(gFunsPtr[].len-1, 0):
      let fun = gFunsPtr[][i]
      case fun.kind
      of kClosure: fun.fun1(e)
      of kNoconv: fun.fun2(e)

template fun() =
  if gFuns.len == 0:
    gFunsPtr = addr gFuns
    unhandledExceptionHook = callClosures

proc addUnhandledExceptionProc*(cl: proc (e: ref Exception)
    {.closure, gcsafe, tags: [], raises: [], locks: 0.}) =
  ## Adds/registers a procedure for unhandled exceptions.
  ## Each call to `addUnhandledExceptionProc` registers another
  ## procedure. They are executed on a last-in, first-out basis.
  withLock gFunsLock:
    fun()
    gFuns.add Fun(kind: kClosure, fun1: cl)

proc addUnhandledExceptionProc*(cl: proc(e: ref Exception)
    {.noconv, gcsafe, tags: [], raises: [], locks: 0.}) =
  ## overload for `noconv` procs.
  withLock gFunsLock:
    fun()
    gFuns.add Fun(kind: kNoconv, fun2: cl)