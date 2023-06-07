when (NimMajor, NimMinor) > (1, 4):
  import std/enumutils
  export enumutils

else:  # Copy from `std/enumutils`
  #
  #
  #            Nim's Runtime Library
  #        (c) Copyright 2020 Nim contributors
  #
  #    See the file "copying.txt", included in this
  #    distribution, for details about the copyright.
  #

  import macros
  from typetraits import OrdinalEnum, HoleyEnum
  export typetraits

  # xxx `genEnumCaseStmt` needs tests and runnableExamples

  macro genEnumCaseStmt*(typ: typedesc, argSym: typed, default: typed,
              userMin, userMax: static[int], normalizer: static[proc(s :string): string]): untyped =
    # generates a case stmt, which assigns the correct enum field given
    # a normalized string comparison to the `argSym` input.
    # string normalization is done using passed normalizer.
    # NOTE: for an enum with fields Foo, Bar, ... we cannot generate
    # `of "Foo".nimIdentNormalize: Foo`.
    # This will fail, if the enum is not defined at top level (e.g. in a block).
    # Thus we check for the field value of the (possible holed enum) and convert
    # the integer value to the generic argument `typ`.
    let typ = typ.getTypeInst[1]
    let impl = typ.getImpl[2]
    expectKind impl, nnkEnumTy
    let normalizerNode = quote: `normalizer`
    expectKind normalizerNode, nnkSym
    result = nnkCaseStmt.newTree(newCall(normalizerNode, argSym))
    # stores all processed field strings to give error msg for ambiguous enums
    var foundFields: seq[string] = @[]
    var fStr = "" # string of current field
    var fNum = BiggestInt(0) # int value of current field
    for f in impl:
      case f.kind
      of nnkEmpty: continue # skip first node of `enumTy`
      of nnkSym, nnkIdent: fStr = f.strVal
      of nnkAccQuoted:
        fStr = ""
        for ch in f:
          fStr.add ch.strVal
      of nnkEnumFieldDef:
        case f[1].kind
        of nnkStrLit: fStr = f[1].strVal
        of nnkTupleConstr:
          fStr = f[1][1].strVal
          fNum = f[1][0].intVal
        of nnkIntLit:
          fStr = f[0].strVal
          fNum = f[1].intVal
        else: error("Invalid tuple syntax!", f[1])
      else: error("Invalid node for enum type `" & $f.kind & "`!", f)
      # add field if string not already added
      if fNum >= userMin and fNum <= userMax:
        fStr = normalizer(fStr)
        if fStr notin foundFields:
          result.add nnkOfBranch.newTree(newLit fStr,  nnkCall.newTree(typ, newLit fNum))
          foundFields.add fStr
        else:
          error("Ambiguous enums cannot be parsed, field " & $fStr &
            " appears multiple times!", f)
      inc fNum
    # finally add else branch to raise or use default
    if default == nil:
      let raiseStmt = quote do:
        raise newException(ValueError, "Invalid enum value: " & $`argSym`)
      result.add nnkElse.newTree(raiseStmt)
    else:
      expectKind(default, nnkSym)
      result.add nnkElse.newTree(default)
