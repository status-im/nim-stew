## Copyright (c) 2020 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements UTF-8 related procedures.

proc validateUtf8*[T: byte|char](data: openarray[T]): bool =
  ## Returns ``true`` if ``data`` is correctly UTF-8 encoded string.
  var index = 0

  while true:
    let byte1 =
      block:
        var b: byte
        while true:
          if index >= len(data):
            return true
          b = when T is byte: data[index] else: byte(data[index])
          inc(index)
          if b >= 0x80'u8:
            break
        b

    if (byte1 and 0xE0'u8) == 0xC0'u8:
      # Two-byte form (110xxxxx 10xxxxxx)
      if index >= len(data):
        return false
      # overlong sequence test
      if (byte1 and 0xFE'u8) == 0xC0'u8:
        return false

      let byte2 = when T is byte: data[index] else: byte(data[index])
      if (byte2 and 0xC0'u8) != 0x80'u8:
        return false
      inc(index)

    elif (byte1 and 0xF0'u8) == 0xE0'u8:
      # Three-byte form (1110xxxx 10xxxxxx 10xxxxxx)
      if (index + 1) >= len(data):
        return false

      let byte2 = when T is byte: data[index] else: byte(data[index])
      if (byte2 and 0xC0'u8) != 0x80'u8:
        return false
      # overlong sequence test
      if (byte1 == 0xE0'u8) and ((byte2 and 0xE0'u8) == 0x80'u8):
        return false
      #  0xD800–0xDFFF (UTF-16 surrogates) test
      if (byte1 == 0xED'u8) and ((byte2 and 0xE0'u8) == 0xA0'u8):
        return false

      let byte3 = when T is byte: data[index + 1] else: byte(data[index + 1])
      if (byte3 and 0xC0'u8) != 0x80'u8:
        return false
      # U+FFFE or U+FFFF test
      if (byte1 == 0xEF'u8) and (byte2 == 0xBF'u8) and
         ((byte3 and 0xFE'u8) == 0xBE'u8):
        return false
      inc(index, 2)

    elif (byte1 and 0xF8'u8) == 0xF0'u8:
      # Four-byte form (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
      if (index + 2) >= len(data):
        return false

      let byte2 = when T is byte: data[index] else: byte(data[index])
      if (byte2 and 0xC0'u8) != 0x80'u8:
        return false
      # overlong sequence test
      if (byte1 == 0xF0'u8) and ((byte2 and 0xF0'u8) == 0x80'u8):
        return false
      # According to RFC 3629 no point above U+10FFFF should be used, which
      # limits characters to four bytes.
      if ((byte1 == 0xF4'u8) and (byte2 > 0x8F'u8)) or (byte1 > 0xF4'u8):
        return false

      let byte3 = when T is byte: data[index + 1] else: byte(data[index + 1])
      if (byte3 and 0xC0'u8) != 0x80'u8:
        return false

      let byte4 = when T is byte: data[index + 2] else: byte(data[index + 2])
      if (byte4 and 0xC0'u8) != 0x80'u8:
        return false
      inc(index, 3)

    else:
      return false
