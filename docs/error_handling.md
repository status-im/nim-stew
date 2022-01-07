## The `errors` pragma

The `errors` pragma is similar to the `raises` pragma, but it uses
the Nim type system to ensure that the raised recoverable errors
will be handled at the call-sites of the annotated function.

To achieve this, it performs the following simple transformation:

```nim
proc foo(x: int, y: string): float {.errors: (ValueError, KeyError).} =
  body
```

is re-written to the equivalent of:

```nim
type
  Raising[ErrorsList, ResultType] = distinct ResultType

proc foo_original(x: int, y: string): float {.
  raises: [Defect, ValueError, KeyError]
.} =
  body

template foo(x: int, y: string): untyped =
  Raising[(ValueError, KeyError), float](foo_original(x, y))
```

Please note that the original proc now features a `raises` annotation
that will guarantee that no other exceptions might be raised from it.
The `Defect` type was implicitly added to the list as a convenience.

The returned distinct type will be useless at the call-site unless
it is stripped-away through `raising`, `either` or `check` which are
the error-handling mechanisms provided by this library and discussed
further in this document.

If you accidentally forget to use one of the error-handling mechanisms,
you'll get a compilation error along these lines:

```
required type for x: float
  but expression 'Raising[(ValueError, KeyError), float](foo_original(x, y))' is of type: Raising[tuple of (ValueError, KeyError), system.float]
```

Please note that if you have assigned the `Raising` result to a
variable, the compilation error might happen on a line where you
attempt to use that variable. To fix the error, please introduce
error handling as early as possible at the right call-site such
that no `Raising` variable is created at all.

`noerrors` is another pragma provided for convenience which is
equivalent to an empty `errors` pragma. The forced error handling
through the `Raising` type won't be applied.

Both pragmas can be combined with the `nodefects` pragma that
indicates that the specific proc should be proven to be Defect-free.

The transformation uses a template by default to promote efficiency,
but if you need to take the address the Raising proc, please add the
`addressable` pragma that will force the wrapper to be a regular proc.

Finally, `failing` is another pragma provided for convenience which
is equivalent to `{.errors: (CatchableError).}`.

## The `raising` annotation

The `raising` annotation is the simplest form of error tracking
similar to the `try` annotation made popular by the [Midori error model](http://joeduffyblog.com/2016/02/07/the-error-model/),
which is also [proposed for addition in C++](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2018/p0709r0.pdf) and [already available in Zig](https://ziglang.org/documentation/master/#try).

It merely marks the locations in the code where errors might be raised
and strips away the `Raising` type to disarm the compiler checks:

```nim
proc attachValidator(node: BeaconNode, keyFile: string) {.failing.} =
  node.addValidator(raising ValidatorPrivKey.init(raising readFile(keyFile))
```

When applied to a `Result` or an `Option`, `raising` will use the
`tryGet` API to attempt to obtain the computed value.

## The capital `Try` API

The capital `Try` API is similar to a regular `try` expression
or a `try` statement. The only difference is that you must provide
exception handlers for all possible recoverable errors. If you fail
to do so, the compiler will point out the line in the `try` block
where an unhandled exception might be raised:

```nim
proc replaceValues(values: var openarray[string],
                   replacements: Table[MyEnum, string]) =
  Try:
    for v in mitems(values):
      let
        enumValue = parseEnum v
        replacement = replacements[enumValue] # Error here
      v = replacement
  except ValueError:
    echo "Invalid enum value"
```

The above example will fail to compile with an error indicating
that `replacements[enumValue]` may fail with an unhandled `KeyError`.

## The `either` expression

The `either` expression can be used with APIs based on `Option[T]`,
`Result[T, E]` or the `errors` pragma when it's appropriate to
discriminate only between successful execution and any type of
failure. Regardless of the error handling scheme being used,
`either` is used like this:

```nim
let x = either(foo(), fallbackValue)
```

On success, `either` returns the successfully computed value
and the failure side of the expression won't be evaluated at all.

Besides providing a substitute value, the failure side of the
expression may also feature a `noReturn` statement such as
`return`, `raise`, `quit` as long at it's used with the following
syntax:

```nim
let x = either foo():
               return
```

Within the failure path, you can also use the `error` keyword to
refer to the raised exception or the `error` value of the failed
`Result`.

## The `check` expression

The `check` macro provides a general mechanism for handling
the failures of APIs based the `errors` pragma or `Result[T, E]`
where `E` is an `enum` or a case object type.

It takes an expression that might fail in multiple ways together
with a block of error handlers that will be executed in case of
failure. If the user failed to cover any of the possible failure
types, this will result in a compilation error.

On success, the `check` returns the successfully computed value
of the checked expression. In case of failure, the appropriate
error handler is executed. It may produce a substitute value or
it may return from the current function with a `return`, `raise`,
`quit` or any other `noReturn` API.

The syntax of the `check` expression is the following:

```nim
let x = check foo():
              SomeError as err: defaultValue
              AnotherError: return
              _: raise
```

If the `foo()` function was using the `errors` pragma, the
above example will be re-written to:

```nim
let x = try:
  raising foo()
except SomeError as err:
  defaultValue
except AnotherError:
  return
except CatchableError:
  raise
```

Alternatively, if `foo()` was returning a `Result[T, E: enum]`, the
example will be re-written to:

```nim
let x = foo()
if x.isOk:
  x.get
else:
  case x.orror:
  of SomeError:
    let err = x.error
    defaultValue
  of AnotherError:
    return
  else:
    raiseResultError x
```

The `Result` error type can also be a case object with a single `enum`
discriminator that will be considered the error type. The generated code
will be quite similar to the example above.

Please note that the special default case `_` is considered equivalent
to `CatchableError` or `else` when working with enums.

