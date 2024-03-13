# Backport of https://github.com/nim-lang/Nim/pull/23356/

import std/strformat

export strformat

template testCompileTime =
  static: debugEcho "extending"
  proc xxx() {.raises: [].} =
    const a = ""
    let x = fmt"{a}" # If this raises, it means compile-time formatting is missing
  xxx()

when not compiles(testCompileTime()):
  import strutils

  proc mkDigit(v: int, typ: char): string {.inline.} =
    assert(v < 26)
    if v < 10:
      result = $chr(ord('0') + v)
    else:
      result = $chr(ord(if typ == 'x': 'a' else: 'A') + v - 10)

  proc formatInt(n: SomeNumber; radix: int; spec: StandardFormatSpecifier): string =
    ## Converts `n` to a string. If `n` is `SomeFloat`, it casts to `int64`.
    ## Conversion is done using `radix`. If result's length is less than
    ## `minimumWidth`, it aligns result to the right or left (depending on `a`)
    ## with the `fill` char.
    when n is SomeUnsignedInt:
      var v = n.uint64
      let negative = false
    else:
      let n = n.int64
      let negative = n < 0
      var v =
        if negative:
          # `uint64(-n)`, but accounts for `n == low(int64)`
          uint64(not n) + 1
        else:
          uint64(n)

    var xx = ""
    if spec.alternateForm:
      case spec.typ
      of 'X': xx = "0x"
      of 'x': xx = "0x"
      of 'b': xx = "0b"
      of 'o': xx = "0o"
      else: discard

    if v == 0:
      result = "0"
    else:
      result = ""
      while v > typeof(v)(0):
        let d = v mod typeof(v)(radix)
        v = v div typeof(v)(radix)
        result.add(mkDigit(d.int, spec.typ))
      for idx in 0..<(result.len div 2):
        swap result[idx], result[result.len - idx - 1]
    if spec.padWithZero:
      let sign = negative or spec.sign != '-'
      let toFill = spec.minimumWidth - result.len - xx.len - ord(sign)
      if toFill > 0:
        result = repeat('0', toFill) & result

    if negative:
      result = "-" & xx & result
    elif spec.sign != '-':
      result = spec.sign & xx & result
    else:
      result = xx & result

    if spec.align == '<':
      for i in result.len..<spec.minimumWidth:
        result.add(spec.fill)
    else:
      let toFill = spec.minimumWidth - result.len
      if spec.align == '^':
        let half = toFill div 2
        result = repeat(spec.fill, half) & result & repeat(spec.fill, toFill - half)
      else:
        if toFill > 0:
          result = repeat(spec.fill, toFill) & result

  proc toRadix(typ: char): int =
    case typ
    of 'x', 'X': 16
    of 'd', '\0': 10
    of 'o': 8
    of 'b': 2
    else:
      raise newException(ValueError,
        "invalid type in format string for number, expected one " &
        " of 'x', 'X', 'b', 'd', 'o' but got: " & typ)

  proc formatValue*[T: SomeInteger](result: var string; value: T;
                                    specifier: static string) =
    ## Standard format implementation for `SomeInteger`. It makes little
    ## sense to call this directly, but it is required to exist
    ## by the `&` macro.
    when specifier.len == 0:
      result.add $value
    else:
      const
        spec = parseStandardFormatSpecifier(specifier)
        radix = toRadix(spec.typ)

      result.add formatInt(value, radix, spec)

  proc formatFloat(
      result: var string, value: SomeFloat, fmode: FloatFormatMode,
      spec: StandardFormatSpecifier) =
    var f = formatBiggestFloat(value, fmode, spec.precision)
    var sign = false
    if value >= 0.0:
      if spec.sign != '-':
        sign = true
        if value == 0.0:
          if 1.0 / value == Inf:
            # only insert the sign if value != negZero
            f.insert($spec.sign, 0)
        else:
          f.insert($spec.sign, 0)
    else:
      sign = true

    if spec.padWithZero:
      var signStr = ""
      if sign:
        signStr = $f[0]
        f = f[1..^1]

      let toFill = spec.minimumWidth - f.len - ord(sign)
      if toFill > 0:
        f = repeat('0', toFill) & f
      if sign:
        f = signStr & f

    # the default for numbers is right-alignment:
    let align = if spec.align == '\0': '>' else: spec.align
    let res = alignString(f, spec.minimumWidth, align, spec.fill)
    if spec.typ in {'A'..'Z'}:
      result.add toUpperAscii(res)
    else:
      result.add res

  proc toFloatFormatMode(typ: char): FloatFormatMode =
    case typ
    of 'e', 'E': ffScientific
    of 'f', 'F': ffDecimal
    of 'g', 'G': ffDefault
    of '\0': ffDefault
    else:
      raise newException(ValueError,
        "invalid type in format string for number, expected one " &
        " of 'e', 'E', 'f', 'F', 'g', 'G' but got: " & typ)

  proc formatValue*(result: var string; value: SomeFloat; specifier: static string) =
    ## Standard format implementation for `SomeFloat`. It makes little
    ## sense to call this directly, but it is required to exist
    ## by the `&` macro.
    when specifier.len == 0:
      result.add $value
    else:
      const
        spec = parseStandardFormatSpecifier(specifier)
        fmode = toFloatFormatMode(spec.typ)

      formatFloat(result, value, fmode, spec)

  proc formatValue*(result: var string; value: string; specifier: static string) =
    ## Standard format implementation for `string`. It makes little
    ## sense to call this directly, but it is required to exist
    ## by the `&` macro.
    const spec = parseStandardFormatSpecifier(specifier)
    var value =
      when spec.typ in {'s', '\0'}: value
      else: static:
        raise newException(ValueError,
          "invalid type in format string for string, expected 's', but got " &
          spec.typ)
    when spec.precision != -1:
      if spec.precision < runeLen(value):
        const precision = cast[Natural](spec.precision)
        setLen(value, Natural(runeOffset(value, precision)))

    result.add alignString(value, spec.minimumWidth, spec.align, spec.fill)

proc formatValue[T: not SomeInteger](result: var string; value: T; specifier: static string) =
  mixin `$`
  formatValue(result, $value, specifier)

