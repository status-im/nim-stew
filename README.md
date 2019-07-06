# stew - status e-something w-something

`stew` is collection of utilities, std library extensions and budding libraries
that are frequently used at Status, but are too small to deserve their own
git repository.

We use `stew` as a staging ground for code that has yet to be battle-tested.

Some of these libraries may eventually be proposed for inclusion in Nim or
broken out into separate repositories.

## Layout

`stew` modules are made to be fairly independent of each other, but generally
follow the following layout - if you've used C++'s `boost`, you'll feel right at
home:

```
# Single-module libraries
stew/small.nim # small libraries that fits in one module

# Multi-module libraries
stew/libname.nim # Main import file
stew/libname/stuff.nim # Detail import file

# Nim standard library shims that contain forwards-compatibility code to manage
# support for multiple nim versions - code in here typically has been taken
# from nim `devel` branch and `name` will reexport the corresponding std lib
# module
# stew/shims/macros.nim - module that reexports `macros.nim` adding code from newer nim versions

# Tests are in the tests folder (duh!)
# To execute, run either `all_tests.nim` or specific `test_xxx.nim` files:
nim c -r tests/all_tests
```

## Compatibility

One of the goals of `stew` is to provide backwards and forwards compatibility
for different Nim versions, such that code using `stew` works well with multiple
versions of Nim. If `stew` is not working with the Nim version you're using, we
welcome patches.

## Notable libraries

Libraries are documented either in-module or on a separate README in their
respective folders

- `bitops2` - an updated version of `bitops.nim`, filling in gaps in original code\
- `shims` - backports of nim `devel` code to the stable version that Status is using

## Using stew in your project

We do not recommend using this library as a normal `nimble` dependency - there
are no versioned releases and we will not maintain API/ABI stability. Instead,
make sure you pin your dependency to a specific git hash (for example using a
submodule) or copy the file to your project instead.

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
