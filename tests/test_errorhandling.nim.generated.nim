
## /home/zahary/nimbus/vendor/nim-stew/tests/test_errorhandling.nim(7, 32)
proc toString_16040040(x: int): string {.raises: [Defect, KeyError, OSError].} =
  result = $x

template toString(x: int): untyped =
  Raising[(ValueError, KeyError, OSError), string](toString_16040040(x))

## /home/zahary/nimbus/vendor/nim-stew/tests/test_errorhandling.nim(29, 14)
try:
  [type node](Raising[(ValueError, KeyError, OSError), string](toString_16040040(30)))
except ValueError:
  "got ValueError"
except KeyError as err:
  err.msg
except OSError:
  raise
## /home/zahary/nimbus/vendor/nim-stew/tests/test_errorhandling.nim(36, 14)
let res_16125314 = readFromDevice("test")
if res_16125314.o: get res_16125314
else:
  case error(res_16125314)
  of FileNotFound:
    raise
      (ref ValueError)(msg: "x", parent: nil)
  of HardwareError:
    quit 1
  else:
    @[]
## /home/zahary/nimbus/vendor/nim-stew/tests/test_errorhandling.nim(54, 2)
try:
  proc Try_payload_16170094(z_16170100: var int; y_16170099: var int; m_16170102: var int;
                           a_16170096: int; x_16170098: var int; b_16170097: var[int];
                           n_16170101: int) {.raises: [ValueError, IOError].} =
    echo [a_16170096, b_16170097, x_16170098, y_16170099, z_16170100, n_16170101, m_16170102]
    if (
      20 < a_16170096):
      discard
  
  Try_payload_16170094(z, y, m, a, x, b, n)
except ValueError:
  discard
except IOError:
  discard