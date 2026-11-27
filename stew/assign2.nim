import std/[macrocache, typetraits], ./shims/[macros, sequninit]

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
    # Construct with the resolved type rather than `T` to work around
    # https://github.com/nim-lang/Nim/issues/26417
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
          if distinctBase(t) != distinctBase(s):
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

func supportsMoveInPlaceImpl(typ: NimNode, depth = 0): bool =
  const MaxDepth = 64
  if depth > MaxDepth or typ.typeKind == ntyNone:
    return false

  let impl = typ.getTypeImpl
  case impl.kind
  of nnkObjectTy, nnkTupleTy, nnkTupleConstr:
    let known = CacheSeq("stew.assign2.supportsMoveInPlace." & typ.repr)
    for knownType in known:
      if sameType(knownType, typ):
        return true

    # Index into fields rather than iterate across elements to work around
    # https://github.com/nim-lang/Nim/issues/26273
    let fields = typ.recordFields
    for i in 0 ..< fields.len:
      if not fields[i].typ.supportsMoveInPlaceImpl(depth + 1):
        return false
    known.add typ
    true
  of nnkDistinctTy, nnkPtrTy:
    impl[0].supportsMoveInPlaceImpl(depth + 1)
  of nnkBracketExpr:
    case impl[0].typeKind
    of ntySet, ntyRange:
      true
    of ntyArray, ntySequence, ntyUncheckedArray:
      impl[^1].supportsMoveInPlaceImpl(depth + 1)
    else:
      false
  else:
    impl.typeKind in
      {ntyBool, ntyChar, ntyEnum, ntyInt .. ntyUInt64, ntyString, ntyCString}

macro supportsMoveInPlace(T: type): untyped =
  # Whether destroying a `T` cannot free another `T`,
  # as in `x = move(x.child[])`, where `x` owns the source.
  # Only then can the temporary of `move` be skipped.
  # Hooks that free other objects, e.g., via a global,
  # are not detected; see the manual's aliasing rules:
  # https://nim-lang.org/docs/manual_experimental.html#aliasing-restrictions-in-parameter-passing
  let isSupported = newLit(T.getTypeImpl[1].supportsMoveInPlaceImpl)
  quote do:
    supportsCopyMem(`T`) or `isSupported`

macro unsupportedMove(T: type): untyped =
  error "moveAssign of type " & repr(T.getTypeInst[1]) & " unsupported"

proc moveAssign*[T](tgt: var T, src: var T) =
  ## Moves `src` into `tgt` and resets `src`, same as `tgt = move(src)`,
  ## but without a temporary copy of the value on the stack.
  ##
  ## With ORC, `tgt = move(src)` first moves the value into a temporary
  ## on the stack when `tgt` is reached through a pointer,
  ## e.g., a `var` parameter or a dereferenced `ref`.
  ## That overflows the stack for large values:
  ## https://github.com/nim-lang/Nim/issues/26565
  ##
  ## Calls for types that might need that temporary do not compile.
  ##
  ## `tgt` and `src` must be different locations.
  when not supportsMoveInPlace(T):
    unsupportedMove T

  when nimvm:
    when (NimMajor, NimMinor) >= (2, 4):
      tgt = move(src)
    else:
      # `move` does not reset `src` at compile time:
      # https://github.com/nim-lang/Nim/issues/15975
      # A `src` behind a `ref` is not copied either,
      # so this leaves `tgt` empty for such a `src`:
      # https://github.com/nim-lang/Nim/pull/26323
      var tmp = src
      reset(src)
      tgt = tmp
  else:
    if addr(tgt) == addr(src):
      raiseAssert "Target and source are the same location"

    when not defined(gcDestructors) or supportsCopyMem(T):
      # Under refc, and for types without hooks, `move` needs no temporary
      tgt = move(src)
    else:
      # The manual's "move-optimization" rewrite rule,
      # as destroying `tgt` cannot free `src`:
      # https://nim-lang.org/docs/destructors.html#rewrite-rules
      `=sink`(tgt, src)
      {.cast(raises: []), cast(tags: []).}:  # Same as in `system.move`
        `=wasMoved`(src)
