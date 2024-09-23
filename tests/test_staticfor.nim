{.used.}

import unittest2, ../stew/staticfor

suite "staticfor":
  test "basics":
    var
      a = 0
      b = 0

    for i in 0..10:
      a += i

    staticFor i, 0..10:
      b += default(array[i, byte]).len

    check: a == b