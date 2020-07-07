import
  os, threadpool,
  ../stew/faux_closures

template sendSignal(data: string) =
  echo data

template spawnAndSend(exprToSend: untyped) =
  proc payload {.fauxClosure.} =
    let data = exprToSend
    sendSignal data

  spawn payload()

proc main(x: string) =
  spawnAndSend:
    var i = 10
    x & $(23 + i)

main("tests")
sleep(2)

