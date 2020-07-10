import results
import chronos # requires chornos

type
  AsyncResult*[T] = Future[Result[T, string]]
  AsyncCall*[T1, T2] = proc(prev: AsyncResult[T1]): AsyncResult[T2]

# the whole point is not loose errors around and to be able to declare a chain of async ops clearly
# we do strict error checking and propagate them in the result
# and so we need just a single await in user code

proc andThen*[T1, T2](a: AsyncResult[T1]; b: AsyncCall[T1, T2]): AsyncResult[T2] = 
  var retFuture = newFuture[Result[T2, string]]()
  a.callback = proc(_: pointer) =
    if a.failed():
      let msg = a.readError().msg
      retFuture.complete(err(Result[T2, string], msg))
    else:
      let ares = a.read()
      if ares.isOk():
        try:
          let f = b(a)
          f.callback = proc(_: pointer) =
            if f.failed():
              let msg = f.readError().msg
              retFuture.complete(err(Result[T2, string], msg))
            else:
              let res = f.read()
              retFuture.complete(res)
          f.cancelCallback = proc(_: pointer) =
            f.callback = proc(_: pointer) = discard # empty up callback
            # since we complete here
            retFuture.complete(err(Result[T2, string], "Operation canceled"))
        except CatchableError as ex:
          retFuture.complete(err(Result[T2, string], ex.msg))
      else:
        let err = ares.error()
        retFuture.complete(err(Result[T2, string], err))
  a.cancelCallback = proc(_: pointer) =
    a.callback = proc(_: pointer) = discard # empty up callback
    # since we complete here
    retFuture.complete(err(Result[T2, string], "Operation canceled"))
  return retFuture

proc orElse*[T](a: AsyncResult[T]; b: AsyncCall[T, T]): AsyncResult[T] = 
  var retFuture = newFuture[Result[T, string]]()

  template runB: untyped =
    try:
      let f = b(a)
      f.callback = proc(_: pointer) =
        if f.failed():
          let msg = f.readError().msg
          retFuture.complete(err(Result[T, string], msg))
        else:
          let res = f.read()
          retFuture.complete(res)
      f.cancelCallback = proc(_: pointer) =
        f.callback = proc(_: pointer) = discard # empty up callback
        # since we complete here
        retFuture.complete(err(Result[T, string], "Operation canceled"))
    except CatchableError as ex:
      retFuture.complete(err(Result[T, string], ex.msg))

  a.callback = proc(_: pointer) =
    if a.failed():
      runB()
    else:
      let ares = a.read()
      if ares.isOk():
        retFuture.complete(ares)
      else:
        runB()
  a.cancelCallback = proc(_: pointer) =
    a.callback = proc(_: pointer) = discard # empty up callback
    # since we complete here
    retFuture.complete(err(Result[T, string], "Operation canceled"))
  return retFuture

when isMainModule:
  proc p1(): Future[Result[int, string]] {.async.} =
    echo "p1 enter -> sleep"
    await sleepAsync(1000)
    echo "p1 exit -> ok(10)"
    return ok(10)

  proc p2(prev: AsyncResult[int]): Future[Result[int, string]] {.async.} =
    echo "p2 enter -> await prev"
    let p = await prev # notice these are already completed! NO THROW
    if p.isOk:
      echo "p2 exit -> ok(p.get() + 10)"
      return ok(p.get() + 10)
    else:
      echo "p2 exit -> err('Failed')"
      return err("Failed")

  proc p2FromErr(prev: AsyncResult[int]): Future[Result[int, string]] {.async.} =
    echo "p2FromErr enter -> await prev"
    let p = await prev # notice these are already completed! NO THROW
    if p.isErr:
      echo "p2FromErr exit -> ok(10)"
      return ok(10)
    else:
      assert(false)

  proc p3(prev: AsyncResult[int]): Future[Result[int, string]] {.async.} =
    echo "p3 enter -> await prev"
    let p = await prev # notice these are already completed! NO THROW
    if p.isOk:
      echo "p3 exit -> ok(p.get() + 5)"
      return ok(p.get() + 5)
    else:
      echo "p3 exit -> err('Failed')"
      return err("Failed")

  proc pFail(prev: AsyncResult[int]): Future[Result[int, string]] {.async.} =
    echo "pFail enter -> await prev"
    discard await prev # notice these are already completed! NO THROW
    echo "pFail exit -> err('Failed')"
    return err("Failed")

  proc pExcept(prev: AsyncResult[int]): Future[Result[int, string]] =
    echo "pExcept -> raise"
    raise newException(CatchableError, "ExFailed")

  proc pAsExcept(prev: AsyncResult[int]): Future[Result[int, string]] {.async.} =
    echo "pAsExcept enter -> await prev"
    let r = await prev # notice these are already completed! NO THROW
    if r.get() == 20:
      echo "pAsExcept -> raise"
      raise newException(CatchableError, "AsExFailed")
    else:
      echo "pAsExcept -> raise"
      raise newException(CatchableError, "AsExFailed")

  proc main() {.async.} =
    echo "main"
    let 
      res1 = await p1()
                  .andThen(p2)
                  .andThen(pFail)
                  # all those will be skipped!
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)

    echo res1
    assert res1 == err(Result[int, string], "Failed")

    let 
      res2 = await p1()
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)

    echo res2
    assert res2 == ok(Result[int, string], 40)

    let 
      res3 = await p1()
                  .andThen(p2)
                  .andThen(pExcept)
                  # all those will be skipped!
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)

    echo res3
    assert res3 == err(Result[int, string], "ExFailed")

    let 
      res4 = await p1()
                  .andThen(p2)
                  .andThen(pAsExcept)
                  # all those will be skipped!
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)
                  .andThen(p2)

    echo res4
    assert res4 == err(Result[int, string], "AsExFailed")

    let 
      longOp = sleepAsync(60000)
      f5 = p1()
              .andThen(p2)
              .andThen(p2)
              .andThen(p2)
              .andThen(proc(prev: AsyncResult[int]): Future[Result[int, string]] {.async.} =
                  echo "Starting long await"
                  await longOp
                  return ok(10))
              .andThen(p2)
      c5 = proc() {.async.} =
        await sleepAsync(2000)
        echo "Canceling"
        longOp.cancel()
      waiter = proc() {.async.} =
        try:
          discard await f5
        except CancelledError:
          assert(false)


    let sleepAndCancel = allFutures(longOp, c5())
    let ops = allFutures(waiter(), sleepAndCancel)
    await ops
    let res5 = await f5
    echo res5
    assert res5 == err(Result[int, string], "Operation canceled")

    let
      res6 = await p1().andThen(pExcept).orElse(p2FromErr).andThen(p2)

    echo res6
    assert res6 == ok(Result[int, string], 20)

    let
      res7 = await p1().andThen(p3).orElse(p2).andThen(p2)

    echo res7
    assert res7 == ok(Result[int, string], 25)

  waitFor main()

  # eventually do this macro
  # let res = chain:
  #   c1
  #   c2
  #   c3