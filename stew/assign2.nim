import std/typetraits, ./shims/[macros, sequninit]

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
    for i in 0 ..< tgt.len:
      tgt[i] = src[i]
  else:
    when hasMoveMem and supportsCopyMem(T):
      if tgt.len > 0:
        moveMem(addr tgt[0], addr src[0], sizeof(tgt[0]) * tgt.len)
    else:
      for i in 0 ..< tgt.len:
        assign(tgt[i], src[i])

func assign*[T](tgt: var openArray[T], src: openArray[T]) =
  mixin assign

  if tgt.len != src.len:
    raiseAssert "Target and source lengths don't match: " & $tgt.len & " vs " & $src.len

  assignImpl(tgt, src)

func assign*[T](tgt: var seq[T], src: openArray[T]) =
  mixin assign

  when supportsCopyMem(T):
    # Available from https://github.com/nim-lang/Nim/pull/22767
    tgt.setLenUninit(src.len)
  else:
    tgt.setLen(src.len)

  assignImpl(tgt, src)

func assign*(tgt: var string, src: string) =
  tgt.setLen(src.len)

  assignImpl(tgt, src)

macro unsupported(T: type): untyped =
  error "Assignment of the type " & humaneTypeName(T) & " is not supported"

func discriminatorNames(T: type): seq[string] {.compileTime.} =
  var names: seq[string]
  when T is object:
    # Index into fields rather than iterate across elements to work around
    # https://github.com/nim-lang/Nim/issues/26273
    let fields = recordFields(T)
    for i in 0 ..< fields.len:
      if fields[i].isDiscriminator:
        names.add $fields[i].name
  names

macro initCaseObjectBranch(
    T: type, tgt, src: untyped, names: static seq[string]): untyped =
  let
    res = newStmtList()
    value = nnkObjConstr.newTree(T.getTypeInst[1])
  for name in names:
    let discriminator = nskLet.genSym(name)
    res.add newLetStmt(discriminator, newDotExpr(src, ident(name)))
    value.add newColonExpr(ident(name), discriminator)
  res.add newAssignment(tgt, value)
  res

template assignCaseObject(tgt, src: untyped, names: static seq[string]) =
  {.push warning[ProveField]: off.}
  var areSameKind = true
  for name, t in system.fieldPairs(tgt):
    when name in names:
      for sourceName, s in system.fieldPairs(src):
        when sourceName == name:
          if t != s:
            areSameKind = false
  if not areSameKind:
    when defined(gcDestructors) or  # orc: `=copy` hook, no slow genericAssign
        (NimMajor, NimMinor) < (2, 2) or  # Constructor uses a stack temporary
        # Case inside a branch, must-init fields, inaccessible discriminators
        not compiles(initCaseObjectBranch(typeof(tgt), tgt, src, names)):
      tgt = src
    else:
      initCaseObjectBranch(typeof(tgt), tgt, src, names)
      areSameKind = true
  if areSameKind:
    for name, t in system.fieldPairs(tgt):
      when name notin names:
        for sourceName, s in system.fieldPairs(src):
          when sourceName == name:
            when supportsCopyMem(type s) and sizeof(s) <= sizeof(int) * 2:
              t = s # Shortcut
            else:
              assign(t, s)
  {.pop.}

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
          moveMem(addr tgt, addr src, sizeof(tgt))
      elif T is object | tuple:
        const names = discriminatorNames(T)
        when names.len > 0:
          assignCaseObject(tgt, src, names)
        else:
          for t, s in fields(tgt, src):
            when supportsCopyMem(type s) and sizeof(s) <= sizeof(int) * 2:
              t = s # Shortcut
            else:
              assign(t, s)
      elif T is seq:
        assign(tgt, src.toOpenArray(0, src.high))
      elif T is array:
        assignImpl(tgt, src)
      elif T is ref:
        tgt = src
      elif T is distinct:
        assign(distinctBase tgt, distinctBase src)
      else:
        unsupported T
    else:
      tgt = src
