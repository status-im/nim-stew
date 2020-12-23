# stew - status e-something w-something

[![Build Status (Travis)](https://img.shields.io/travis/status-im/nim-stew/master.svg?label=Linux%20/%20macOS "Linux/macOS build status (Travis)")](https://travis-ci.org/status-im/nim-stew)
[![Windows build status (Appveyor)](https://img.shields.io/appveyor/ci/nimbus/nim-stew/master.svg?label=Windows "Windows build status (Appveyor)")](https://ci.appveyor.com/project/nimbus/nim-stew)
[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
![Github action](https://github.com/status-im/nim-stew/workflows/nim-stew%20CI/badge.svg)

`stew` is collection of utilities, std library extensions and budding libraries
that are frequently used at Status, but are too small to deserve their own
git repository.

We also use `stew` as a staging ground for code that has yet to be
battle-tested.

Some of these libraries may eventually be proposed for inclusion in Nim or
broken out into separate repositories.

## Notable libraries

Libraries are documented either in-module or on a separate README in their
respective folders

- `arrayops` - small helpers and operations on `array`/`openArray`
- `assign2` - fast assignments (unlike the `=` operator in nim which is very slow)
- `bitops2` - an updated version of `bitops.nim`, filling in gaps in original code
- `byteutils` - utilities that make working with the Nim `byte` type convenient
- `endians2` - utilities for converting to and from little / big endian integers
- `objects` - get an object's base type at runtime, as a string
- `ptrops` - pointer arithmetic utilities
- `result` - friendly, exception-free value-or-error returns, similar to `Option[T]`, from [nim-result](https://github.com/arnetheduck/nim-result/)
- `shims` - backports of nim `devel` code to the stable version that Status is using
- `sequtils2` - extensions to the `sequtils` module for working conveniently with `seq`
- `varints` - helpers for working with variable length integers

## Layout

`stew` modules are made to be fairly independent of each other, but generally
follow the following layout - if you've used C++'s `boost`, you'll feel right at
home:

```bash
# Single-module libraries
stew/small.nim # small libraries that fits in one module

# Multi-module libraries
stew/libname.nim # Main import file
stew/libname/stuff.nim # Detail import file

# Nim standard library shims that contain forwards-compatibility code to manage
# support for multiple nim versions - code in here typically has been taken
# from nim `devel` branch and `name` will reexport the corresponding std lib
# module
stew/shims/macros.nim # module that reexports `macros.nim` adding code from newer nim versions

# Tests are in the tests folder (duh!)
# To execute, run either `all_tests.nim` or specific `test_xxx.nim` files:
nim c -r tests/all_tests
```

## Compatibility

One of the goals of `stew` is to provide backwards and forwards compatibility
for different Nim versions, such that code using `stew` works well with multiple
versions of Nim. If `stew` is not working with the Nim version you're using, we
welcome patches.

You can create multiple versions of your code using the following pattern:

```nim
when (NimMajor,NimMinor,NimPatch) >= (0,19,9):
  discard
elif (NimMajor,NimMinor,NimPatch) >= (0,19,0):
  discard
else
  {.fatal: "unsupported nim version"}
```

## Using stew in your project

We do not recommend using this library as a normal `nimble` dependency - there
are no versioned releases and we will not maintain API/ABI stability. Instead,
make sure you pin your dependency to a specific git hash (for example using a
submodule) or copy the file to your project instead.

Typically, you will import either a top-level library or drill down into its
submodules:
```nim
import stew/bitops2
import stew/ranges/bitranges
```

:warning: No API/ABI stability - pick a commit and stick with it :warning:

## Contributing to stew

We welcome contributions to stew - in particular:
* if you feel that some part of `stew` should be part of Nim, we welcome your help in taking it through the Nim PR process.
* if you're using `stew` with a particular Nim version, we welcome compatibility patches gated with `when NimMajor .. and NimMinor ..`

## License

Licensed and distributed under either of

* MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

* Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. These files may not be copied, modified, or distributed except according to those terms.
