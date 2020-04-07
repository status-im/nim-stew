import
  ../stew/[shims/macros, errorhandling]

proc bar(x: int): int {.noerrors.} =
  100

proc toString(x: int): string {.errors: (ValueError, KeyError, OSError).} =
  $x

enum
  ReadStatus = enum
    FileNotFound
    AccessDenied
    HardwareError

proc readFromDevice(path: string): Result[seq[byte], ReadStatus] =
  err AccessDenied

proc getGpsCoordinates(): Result[(float, float), cstring] =
  ok (1.2, 3.4)

proc main =
  let
    a = bar(10)
    b = raising toString(20)
    c = chk toString(30):
            ValueError: "got ValueError"
            KeyError as err: err.msg
            OSError: raise

    d = chk(readFromDevice("test"), @[1.byte, 2, 3])
    
    e = chk readFromDevice("test"):
            FileNotFound: raise newException()
            HardwareError: quit 1
            else: @[]

  echo a
  echo b
  echo c

main()

dumpMacroResults()

when false:
  type
    ExtraErrors = KeyError|OSError

  #[
  proc map[A, E, R](a: A, f: proc (a: A): Raising[E, R])): string {.
    errors: E|ValueError|ExtraErrors
  .} =
    $chk(f(a))
  ]#

