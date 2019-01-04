proc init*[ClosureType: proc](T: type ClosureType; p, env: pointer): T =
  {.emit: "`result`->ClP_0 = `p`; `result`->ClE_0 = `env`;".}

when isMainModule:
  type
    SomeClosure = proc(y: string): int

  proc makeClosure(x: int): SomeClosure =
    result = proc(y: string): int =
      return x + y.len + 10

  var f1 = makeClosure(20)
  doAssert f1("test") == 34

  type
    CustomEnvironment = object
      captured: int

  proc rawClosureProc(y: string, env: pointer): int =
    return cast[ptr CustomEnvironment](env).captured + y.len + 10

  var env = create CustomEnvironment
  env.captured = 10

  var f2: SomeClosure = SomeClosure.init(rawClosureProc, cast[pointer](env))
  doAssert f2("test") == 24

