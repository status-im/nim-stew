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

import std/parseutils; export parseutils
#From https://github.com/nim-lang/Nim/pull/21349 in -devel and in version-1-6:
#  https://github.com/nim-lang/Nim/commit/c546ba5d23bb2e7bc562a071c88efd94cca7b89e
#  https://github.com/nim-lang/Nim/commit/fca6a0bd6a6d3b9a25d1272e29bc39e88853188e
when not declared(parseSize): # Odd code formatting to minimize diff v. mainLine
 const Whitespace = {' ', '\t', '\v', '\r', '\l', '\f'}

 func toLowerAscii(c: char): char =
  if c in {'A'..'Z'}: char(uint8(c) xor 0b0010_0000'u8) else: c

 func parseSize*(s: string, size: var int64, alwaysBin=false): int =
  ## Parse a size qualified by binary or metric units into `size`.  This format
  ## is often called "human readable".  Result is the number of processed chars
  ## or 0 on parse errors and size is rounded to the nearest integer.  Trailing
  ## garbage like "/s" in "1k/s" is allowed and detected by `result < s.len`.
  ##
  ## To simplify use, following non-rare wild conventions, and since fractional
  ## data like milli-bytes is so rare, unit matching is case-insensitive but for
  ## the 'i' distinguishing binary-metric from metric (which cannot be 'I').
  ##
  ## An optional trailing 'B|b' is ignored but processed.  I.e., you must still
  ## know if units are bytes | bits or infer this fact via the case of s[^1] (if
  ## users can even be relied upon to use 'B' for byte and 'b' for bit or have
  ## that be s[^1]).
  ##
  ## If `alwaysBin==true` then scales are always binary-metric, but e.g. "KiB"
  ## is still accepted for clarity.  If the value would exceed the range of
  ## `int64`, `size` saturates to `int64.high`.  Supported metric prefix chars
  ## include k, m, g, t, p, e, z, y (but z & y saturate unless the number is a
  ## small fraction).
  ##
  ## **See also:**
  ## * https://en.wikipedia.org/wiki/Binary_prefix
  ## * `formatSize module<strutils.html>`_ for formatting
  runnableExamples:
    var res: int64  # caller must still know if 'b' refers to bytes|bits
    doAssert parseSize("10.5 MB", res) == 7
    doAssert res == 10_500_000  # decimal metric Mega prefix
    doAssert parseSize("64 mib", res) == 6
    doAssert res == 67108864    # 64 shl 20
    doAssert parseSize("1G/h", res, true) == 2 # '/' stops parse
    doAssert res == 1073741824  # 1 shl 30, forced binary metric
  const prefix = "b" & "kmgtpezy"       # byte|bit & lowCase metric-ish prefixes
  const scaleM = [1.0, 1e3, 1e6, 1e9, 1e12, 1e15, 1e18, 1e21, 1e24] # 10^(3*idx)
  const scaleB = [1.0, 1024, 1048576, 1073741824, 1099511627776.0,  # 2^(10*idx)
                  1125899906842624.0, 1152921504606846976.0,        # ldexp?
                  1.180591620717411303424e21, 1.208925819614629174706176e24]
  var number: float
  var scale = 1.0
  result = parseFloat(s, number)
  if number < 0:                        # While parseFloat accepts negatives ..
    result = 0                          #.. we do not since sizes cannot be < 0
  if result > 0:
    let start = result                  # Save spot to maybe unwind white to EOS
    while result < s.len and s[result] in Whitespace:
      inc result
    if result < s.len:                  # Illegal starting char => unity
      if (let si = prefix.find(s[result].toLowerAscii); si >= 0):
        inc result                      # Now parse the scale
        scale = if alwaysBin: scaleB[si] else: scaleM[si]
        if result < s.len and s[result] == 'i':
          scale = scaleB[si]            # Switch from default to binary-metric
          inc result
        if result < s.len and s[result].toLowerAscii == 'b':
          inc result                    # Skip optional '[bB]'
    else:                               # Unwind result advancement when there..
      result = start                    #..is no unit to the end of `s`.
    var sizeF = number * scale + 0.5    # Saturate to int64.high when too big
    size = if sizeF > 9223372036854774784.0: int64.high else: sizeF.int64
# Above constant=2^63-1024 avoids C UB; github.com/nim-lang/Nim/issues/20102 or
# stackoverflow.com/questions/20923556/math-pow2-63-1-math-pow2-63-512-is-true
