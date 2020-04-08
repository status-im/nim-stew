import
  ../stew/[shims/macros, errorhandling]

proc bar(x: int): int {.noerrors.} =
  100

proc toString(x: int): string {.errors: (ValueError, KeyError, OSError).} =
  $x

type
  ReadStatus = enum
    FileNotFound
    AccessDenied
    HardwareError

proc readFromDevice(path: string): Result[seq[byte], ReadStatus] =
  err AccessDenied

proc getGpsCoordinates(): Result[(float, float), cstring] =
  ok (1.2, 3.4)

proc takeString(x: string) =
  echo x

proc main =
  let
    a = bar(10)
    b = raising toString(20)
    c = check toString(30):
              ValueError: "got ValueError"
              KeyError as err: err.msg
              OSError: raise

    d = either(readFromDevice("test"), @[1.byte, 2, 3])

    e = check readFromDevice("test"):
              FileNotFound: raise newException(ValueError, "x")
              HardwareError: quit 1
              _: @[]
  echo a
  echo b
  echo c

main()

let n = 10
var m = 23

proc main2(a: int, b: var int) =
  var x = 10
  var y = 20
  var z = 23

  Try:
    echo a, b, x, y, z, n, m
    if a > 20:
      # raise newException(OSError, "Test")
      discard
  except ValueError:
    discard
  except IOError:
    discard

var
  p = 1
  k = 2

main2 p, k

dumpMacroResults()

when false:
  type
    ExtraErrors = KeyError|OSError

  #[
  proc map[A, E, R](a: A, f: proc (a: A): Raising[E, R])): string {.
    errors: E|ValueError|ExtraErrors
  .} =
    $check(f(a))
  ]#

