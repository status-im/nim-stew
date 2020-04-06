
## /home/zahary/nimbus/vendor/nim-stew/tests/test_errorhandling.nim(7, 32)
proc toString_15835040(x: int): string {.raises: [Defect, KeyError, OSError].} =
  result = $x

template toString(x: int): untyped =
  Raising[(ValueError, KeyError, OSError), string](toString_15835040(x))

## /home/zahary/nimbus/vendor/nim-stew/tests/test_errorhandling.nim(14, 12)
try:
  [type node](Raising[(ValueError, KeyError, OSError), string](toString_15835040(30)))
except ValueError:
  "got ValueError"
except KeyError as err:
  err.msg
except OSError:
  raise