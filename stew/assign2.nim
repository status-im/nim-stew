import
  std/typetraits

{.push raises: [Defect].}

func assign*[T](tgt: var openArray[T], src: openArray[T]) =
  mixin assign

  if tgt.len != src.len:
    raiseAssert "Target and source lengths don't match: " &
      $tgt.len & " vs " & $src.len

  when supportsCopyMem(T):
    if tgt.len > 0:
      copyMem(addr tgt[0], unsafeAddr src[0], sizeof(tgt[0]) * tgt.len)
  else:
    for i in 0..<tgt.len:
      assign(tgt[i], src[i])

func assign*[T](tgt: var seq[T], src: openArray[T]) =
  mixin assign
  tgt.setLen(src.len)

  assign(tgt.toOpenArray(0, tgt.high), src)

func assign*[T](tgt: var T, src: T) =
  # The default `genericAssignAux` that gets generated for assignments in nim
  # is ridiculously slow. When syncing, the application was spending 50%+ CPU
  # time in it - `assign`, in the same test, doesn't even show in the perf trace
  mixin assign

  when supportsCopyMem(T):
    when sizeof(src) <= sizeof(int):
      tgt = src
    else:
      copyMem(addr tgt, unsafeAddr src, sizeof(tgt))
  elif T is object|tuple:
    for t, s in fields(tgt, src):
      when supportsCopyMem(type s) and sizeof(s) <= sizeof(int) * 2:
        t = s # Shortcut
      else:
        assign(t, s)
  elif T is seq:
    assign(tgt, src.toOpenArray(0, src.high))
  elif T is ref:
    tgt = src
  elif compiles(distincBase(T)):
    assign(distinctBase tgt, distinctBase src)
  else:
    {.error: "Unsupported type for assignment".}
