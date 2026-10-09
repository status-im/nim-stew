# Copyright (c) 2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

template helperZero*() {.pragma.}

type
  MyType* = object
    helperField* {.helperZero.}: int

  HelperBaseType* = object of RootObj
    helperBaseField* {.helperZero.}: int
    helperPrivateField {.helperZero.}: int
