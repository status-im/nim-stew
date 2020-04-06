import
  ../stew/[shims/macros, errorhandling]

proc bar(x: int): int {.noerrors.} =
  100

proc toString(x: int): string {.errors: (ValueError, KeyError, OSError).} =
  $x

proc main =
  let
    a = bar(10)
    b = raising toString(20)
    c = chk toString(30):
            ValueError: "got ValueError"
            KeyError as err: err.msg
            OSError: raise

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

