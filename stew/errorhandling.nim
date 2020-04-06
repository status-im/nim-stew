import
  typetraits, strutils,
  shims/macros, results

const
  enforce_error_handling {.strdefine.}: string = "yes"
  errorHandlingEnforced = parseBool(enforce_error_handling)

type
  VoidResult = object
  Raising*[ErrorList: tuple, ResultType] = distinct ResultType

let
  raisesPragmaId {.compileTime.} = ident"raises"

proc mergeTupleTypeSets(lhs, rhs: NimNode): NimNode =
  result = newTree(nnkPar)

  for i in 1 ..< lhs.len:
    result.add lhs[i]

  for i in 1 ..< rhs.len:
    block findMatch:
      for j in 1 ..< lhs.len:
        if sameType(rhs[i], lhs[i]):
          break findMatch

      result.add rhs[i]

macro `++`*(lhs: type[tuple], rhs: type[tuple]): type =
  result = mergeTupleTypeSets(getType(lhs)[1], getType(rhs)[1])

proc genForwardingCall(procDef: NimNode): NimNode =
  result = newCall(procDef.name)
  for param, _ in procDef.typedParams:
    result.add param

macro noerrors*(procDef: untyped) =
  let raisesPragma = procDef.pragma.findPragma(raisesPragmaId)
  if raisesPragma != nil:
    error "You should not specify `noerrors` and `raises` at the same time",
           raisesPragma
  var raisesList = newTree(nnkBracket, bindSym"Defect")
  procDef.addPragma newColonExpr(ident"raises", raisesList)
  return procDef

macro errors*(ErrorsTuple: typed, procDef: untyped) =
  let raisesPragma = procDef.pragma.findPragma(raisesPragmaId)
  if raisesPragma != nil:
    error "You should not specify `errors` and `raises` at the same time",
           raisesPragma

  var raisesList = newTree(nnkBracket, bindSym"Defect")

  for i in 1 ..< ErrorsTuple.len:
    raisesList.add ErrorsTuple[i]

  procDef.addPragma newColonExpr(ident"raises", raisesList)

  when errorHandlingEnforced:
    # We are going to create a wrapper proc or a template
    # that calls the original one and wraps the returned
    # value in a Raising type. To achieve this, we must
    # generate a new name for the original proc:

    let
      generateTemplate = true
      OrigResultType = procDef.params[0]

    # Create the wrapper
    var
      wrapperDef: NimNode
      RaisingType: NimNode

    if generateTemplate:
      wrapperDef = newNimNode(nnkTemplateDef, procDef)
      procDef.copyChildrenTo wrapperDef
      # We must remove the raises list from the original proc
      wrapperDef.pragma = newEmptyNode()
    else:
      wrapperDef = copy procDef

    # Change the original proc name
    procDef.name = genSym(nskProc, $procDef.name)

    var wrapperBody = newNimNode(nnkStmtList, procDef.body)
    if OrigResultType.kind == nnkEmpty or eqIdent(OrigResultType, "void"):
      RaisingType = newTree(nnkBracketExpr, ident"Raising",
                            ErrorsTuple, bindSym"VoidResult")
      wrapperBody.add(
        genForwardingCall(procDef),
        newCall(RaisingType, newTree(nnkObjConstr, bindSym"VoidResult")))
    else:
      RaisingType = newTree(nnkBracketExpr, ident"Raising",
                            ErrorsTuple, OrigResultType)
      wrapperBody.add newCall(RaisingType, genForwardingCall(procDef))

    wrapperDef.params[0] = if generateTemplate: ident"untyped"
                           else: RaisingType
    wrapperDef.body = wrapperBody

    result = newStmtList(procDef, wrapperDef)
  else:
    result = procDef

  storeMacroResult result

macro checkForUnhandledErrors(origHandledErrors, raisedErrors: typed) =
  # This macro is executed with two tuples:
  #
  # 1. The list of errors handled at the call-site which will
  #    have a line info matching the call-site.
  # 2. The list of errors that the called function is raising.
  #    The lineinfo here points to the definition of the function.

  # For accidental reasons, the first tuple will be recognized as a
  # typedesc, while the second won't be (beware because this can be
  # considered a bug in Nim):
  var handledErrors = getTypeInst(origHandledErrors)
  if handledErrors.kind == nnkBracketExpr:
    handledErrors = handledErrors[1]

  assert handledErrors.kind == nnkTupleConstr and
         raisedErrors.kind == nnkTupleConstr

  # Here, we'll store the list of errors that the user missed:
  var unhandledErrors = newTree(nnkPar)

  # We loop through the raised errors and check whether they have
  # an appropriate handler:
  for raised in raisedErrors:
    block findHandler:
      template tryFindingHandler(raisedType) =
        for handled in handledErrors:
          if sameType(raisedType, handled):
            break findHandler

      tryFindingHandler raised
      # A base type of the raised exception may be handled instead
      for baseType in raised.baseTypes:
        tryFindingHandler baseType

      unhandledErrors.add raised

  if unhandledErrors.len > 0:
    let errMsg = "The following errors are not handled: $1" % [unhandledErrors.repr]
    error errMsg, origHandledErrors

template raising*[E, R](x: Raising[E, R]): R =
  ## `raising` is used to mark locations in the code that might
  ## raise exceptions. It disarms the type-safety checks imposed
  ## by the `errors` pragma.
  distinctBase(x)

macro chk*[R, E](x: Raising[R, E], handlers: untyped): untyped =
  ## The `chk` macro can be used in 2 different ways
  ##
  ## 1) Try to get the result of an expression. In case of any
  ##    errors, substitute the result with a default value:
  ##
  ##    ```
  ##    let x = chk(foo(), defaultValue)
  ##    ```
  ##
  ##    We'll handle this case with a simple rewrite to
  ##
  ##    ```
  ##    let x = try: distinctBase(foo())
  ##            except CatchableError: defaultValue
  ##    ```
  ##
  ## 2) Try to get the result of an expression while providing exception
  ##    handlers that must cover all possible recoverable errors.
  ##
  ##    ```
  ##    let x = chk foo():
  ##                KeyError as err: defaultValue
  ##                ValueError: return
  ##                _: raise
  ##    ```
  ##
  ##    The above example will be rewritten to:
  ##
  ##    ```
  ##    let x = try:
  ##      foo()
  ##    except KeyError as err:
  ##      defaultValue
  ##    except ValueError:
  ##      return
  ##    except CatchableError:
  ##      raise
  ##    ```
  ##
  ##    Please note that the special case `_` is considered equivalent to
  ##    `CatchableError`.
  ##
  ##    If the `chk` block lacks a default handler and there are unlisted
  ##    recoverable errors, the compiler will fail to compile the code with
  ##    a message indicating the missing ones.
  let
    RaisingType = getTypeInst(x)
    ErrorsSetTuple = RaisingType[1]
    ResultType = RaisingType[2]

  # The `try` branch is the same in all scenarios. We generate it here.
  # The target AST looks roughly like this:
  #
  # TryStmt
  #   StmtList
  #     Call
  #       Ident "distinctBase"
  #       Call
  #         Ident "foo"
  #   ExceptBranch
  #     Ident "CatchableError"
  #     StmtList
  #       Ident "defaultValue"
  result = newTree(nnkTryStmt, newStmtList(
                   newCall(bindSym"distinctBase", x)))

  # Check how the API was used:
  if handlers.kind != nnkStmtList:
    # This is usage type 1: chk(foo(), defaultValue)
    result.add newTree(nnkExceptBranch,
                       bindSym("CatchableError"),
                       newStmtList(handlers))
  else:
    var
      # This will be a tuple of all the errors handled by the `chk` block.
      # In the end, we'll compare it to the Raising list.
      HandledErrorsTuple = newNimNode(nnkPar, x)
      # Has the user provided a default `_: value` handler?
      defaultCatchProvided = false

    for handler in handlers:
      template err(msg: string) = error msg, handler
      template unexpectedSyntax = err(
        "The `chk` handlers block should consist of `ExceptionType: Value/Block` pairs")

      case handler.kind
      of nnkCommentStmt:
        continue
      of nnkInfix:
        if eqIdent(handler[0], "as"):
          if handler.len != 4:
            err "The expected syntax is `ExceptionType as exceptionVar: Value/Block`"
          let
            ExceptionType = handler[1]
            exceptionVar = handler[2]
            valueBlock = handler[3]

          HandledErrorsTuple.add ExceptionType
          result.add newTree(nnkExceptBranch, infix(ExceptionType, "as", exceptionVar),
                             valueBlock)
        else:
          err "The '$1' operator is not expected in a `chk` block" % [$handler[0]]
      of nnkCall:
        if handler.len != 2:
          unexpectedSyntax
        let ExceptionType = handler[0]
        if eqIdent(ExceptionType, "_"):
          if defaultCatchProvided:
            err "Only a single default handler is expected"
          handler[0] = bindSym"CatchableError"
          defaultCatchProvided = true

        result.add newTree(nnkExceptBranch, handler[0], handler[1])
        HandledErrorsTuple.add handler[0]
      else:
        unexpectedSyntax

    result = newTree(nnkStmtListExpr,
                     newCall(bindSym"checkForUnhandledErrors", HandledErrorsTuple, ErrorsSetTuple),
                     result)

  storeMacroResult result
