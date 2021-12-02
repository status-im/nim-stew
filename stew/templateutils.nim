type CppVar[T] = distinct ptr T

iterator evalTemplateParamOnceImpl[T](x: T): lent T =
  yield x

when defined(cpp):
  # TODO `nim cpp` miscompiles iterators returning `var`,
  #      so we need to emulate them in terms of pointers:
  iterator evalTemplateParamOnceImpl[T](x: var T): CppVar[T] =
    yield CppVar[T](addr(x))

  template stripCppVar[T](p: CppVar[T]): var T =
    ((ptr T)(p))[]
else:
  iterator evalTemplateParamOnceImpl[T](x: var T): var T =
    yield x

template evalTemplateParamOnce*(templateParam, newName, blk: untyped) =
  ## This can be used in templates to avoid the problem of multiple
  ## evaluation of template parameters. Compared to the naive approach
  ## of introducing an additional local variable, it has two benefits:
  ##
  ## * It avoids copying whenever possible.
  ## * It works for var parameters.
  ##
  ## Usage example:
  ##
  ## template foo(xParam: SomeType) =
  ##   evalTemplateParamOnce(xParam, x):
  ##     echo x
  ##     echo x
  ##
  ##  A currently existing limitation is that the `evalTemplateParamOnce`
  ##  block is considered a `void` expression, so templates returning
  ##  expressions may find it difficult to benefit fully from the construct.
  ##
  ##  Please also note that using conrol-flow statements such as `return`,
  ##  `continue` and `break` within the template code is possible, but
  ##  extra care must be taken to ensure that they are not referring to the
  ##  inserted `for` loop (you may need to introduce enclosing named blocks
  ##  for correct implementation of both `break` and `continue`).
  ##
  ##  Both limitations will be lifted in a future implementation based on
  ##  view types.
  block:
    for paramAddr in evalTemplateParamOnceImpl(templateParam):
      template newName: auto =
        when paramAddr is CppVar:
          stripCppVar(paramAddr)
        else:
          paramAddr

      blk
