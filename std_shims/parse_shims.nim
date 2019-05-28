# From: https://github.com/nim-lang/Nim/pull/11067/
proc parseHex*[T: SomeInteger](s: string, number: var T, start = 0, maxLen = 0): int
  {.inline, noSideEffect.} =
  ## Parses a hexadecimal number and stores its value in ``number``.
  ##
  ## Returns the number of the parsed characters or 0 in case of an error.
  ## If error, the value of ``number`` is not changed.
  ##
  ## If ``maxLen == 0``, the parsing continues until the first non-hex character
  ## or to the end of the string. Otherwise, no more than ``maxLen`` characters
  ## are parsed starting from the ``start`` position.
  ##
  ## It does not check for overflow. If the value represented by the string is
  ## too big to fit into ``number``, only the value of last fitting characters
  ## will be stored in ``number`` without producing an error.
  runnableExamples:
    var num: int
    doAssert parseHex("4E_69_ED", num) == 8
    doAssert num == 5138925
    doAssert parseHex("X", num) == 0
    doAssert parseHex("#ABC", num) == 4
    var num8: int8
    doAssert parseHex("0x_4E_69_ED", num8) == 11
    doAssert num8 == 0xED'i8
    doAssert parseHex("0x_4E_69_ED", num8, 3, 2) == 2
    doAssert num8 == 0x4E'i8
    var num8u: uint8
    doAssert parseHex("0x_4E_69_ED", num8u) == 11
    doAssert num8u == 237
    var num64: int64
    doAssert parseHex("4E69ED4E69ED", num64) == 12
    doAssert num64 == 86216859871725
  var i = start
  var output = T(0)
  var foundDigit = false
  let last = min(s.len, if maxLen == 0: s.len else: i + maxLen)
  if i + 1 < last and s[i] == '0' and (s[i+1] in {'x', 'X'}): inc(i, 2)
  elif i < last and s[i] == '#': inc(i)
  while i < last:
    case s[i]
    of '_': discard
    of '0'..'9':
      output = output shl 4 or T(ord(s[i]) - ord('0'))
      foundDigit = true
    of 'a'..'f':
      output = output shl 4 or T(ord(s[i]) - ord('a') + 10)
      foundDigit = true
    of 'A'..'F':
      output = output shl 4 or T(ord(s[i]) - ord('A') + 10)
      foundDigit = true
    else: break
    inc(i)
  if foundDigit:
    number = output
    result = i - start
