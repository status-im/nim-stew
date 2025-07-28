import
  std/typetraits,
  ./shims/macros

{.push raises: [], gcsafe.}

func assign*[T](tgt: var seq[T], src: openArray[T])
func assign*[T](tgt: var openArray[T], src: openArray[T])
func assign*[T](tgt: var T, src: T)

template hasMoveMem(): bool =
    not defined(js) and not defined(nimscript)

func assignImpl[T](tgt: var openArray[T], src: openArray[T]) =
  mixin assign
  when nimvm:
    # TODO does not work when tgt overlaps src!
    for i in 0..<tgt.len:
      tgt[i] = src[i]
  else:
    when hasMoveMem and supportsCopyMem(T):
      if tgt.len > 0:
        moveMem(addr tgt[0], unsafeAddr src[0], sizeof(tgt[0]) * tgt.len)
    else:
      for i in 0..<tgt.len:
        assign(tgt[i], src[i])

func assign*[T](tgt: var openArray[T], src: openArray[T]) =
  mixin assign

  if tgt.len != src.len:
    raiseAssert "Target and source lengths don't match: " &
      $tgt.len & " vs " & $src.len

  assignImpl(tgt, src)

func assign*[T](tgt: var seq[T], src: openArray[T]) =
  mixin assign

  when supportsCopyMem(T) and compiles(tgt.setLenUninit(src.len)):
    # Available from https://github.com/nim-lang/Nim/pull/22767
    tgt.setLenUninit(src.len)
  else:
    tgt.setLen(src.len)

  assignImpl(tgt, src)

func assign*(tgt: var string, src: string) =
  tgt.setLen(src.len)

  assignImpl(tgt, src)

macro unsupported(T: typed): untyped =
  error "Assignment of the type " & humaneTypeName(T) & " is not supported"

func assign*[T](tgt: var T, src: T) =
  # The default `genericAssignAux` that gets generated for assignments in nim
  # is ridiculously slow. When syncing, the application was spending 50%+ CPU
  # time in it - `assign`, in the same test, doesn't even show in the perf trace
  mixin assign
  when nimvm:
    tgt = src
  else:
    when hasMoveMem:
      when supportsCopyMem(T):
        when sizeof(src) <= sizeof(int):
          tgt = src
        else:
          moveMem(addr tgt, unsafeAddr src, sizeof(tgt))
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
      elif compiles(distinctBase(tgt)):
        assign(distinctBase tgt, distinctBase src)
      else:
        unsupported T
    else:
      tgt = src
