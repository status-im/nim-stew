# stew - status e-something w-something

[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
![Github action](https://github.com/status-im/nim-stew/workflows/CI/badge.svg)

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

- `arraybuf` - `array`-based fixed-capacity dynamic-length buffer
- `arrayops` - small helpers and operations on `array`/`openArray`
- `assign2` - fast assignments (unlike the `=` operator in nim which is very slow)
- `bitops2` - an updated version of `bitops.nim`, filling in gaps in original code
- `byteutils` - utilities that make working with the Nim `byte` type convenient
- `endians2` - utilities for converting to and from little / big endian integers
- `io2` - I/O without exceptions
- `leb128` - utilities for working with LEB128-based formats (such as the varint style found in protobuf)
- `objects` - get an object's base type at runtime, as a string
- `ptrops` - pointer arithmetic utilities
- `shims` - backports of nim `devel` code to the stable version that Status is using
- `sequtils2` - extensions to the `sequtils` module for working conveniently with `seq`
- `staticfor` - compile-time loop unrolling

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

`stew`, due to its experimental nature, does **not** have a stable API/ABI and
features may be changed or removed. Releases are done on a case-by-case basis
for when some specific project needs them - open an issue if you need one!

When making a release, we will strive to update the `minor` version whenever a
major component is removed or changed and the `patch` version if changes are
mostly additive, but due to the nature of the library being a collection of
smaller libraries, these guidelines may be streched at times.

It is not expected that the library will reach a `1.0` release. Instead, mature
code will be [graduated](https://github.com/status-im/nim-stew/commit/2cf408b9609fc3e6c238ddbd90ab31802e650212)
into independent libraries that can follow a regular release schedule.

* libraries that depend on `stew` should specify the lowest possible required
  version (`stew >= 0.2`) that contain the necessary features that they use -
  this may be lower than latest released version. An upper bound
  (`stew >= 0.2 & <0.3`) or caret versions (`stew ^0.2`) may be used but it is
  not recommended since this will make your library harder to compose with other
  libraries that depend on `stew`.
* applications that depend on stew directly or indirectly should specify a
  commit ( `stew#abc...`) or a specific version (`stew == 0.2.3`) - this ensures
  the application will continue to work irrespective of stew updates
* alternatively, you can just copy the relevant files of stew into your project
  or use a submodule - this approach maximises composability since each consumer
  of stew no longer has to restrict the specific version for other consumers

Typically, you will import either a top-level library or drill down into its
submodules:
```nim
import stew/bitops2
import stew/ranges/bitranges
```

:warning: No API/ABI stability - in applications, pick a commit and stick with it :warning:

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
