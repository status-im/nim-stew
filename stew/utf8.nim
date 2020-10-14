## Copyright (c) 2020 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements UTF-8 related procedures.
import results, io2
export results

type
  UResult*[T] = Result[T, cstring]
  Wides32* = int32 | uint32
  Wides16* = int16 | uint16
  Bytes* = int8 | char | uint8 | byte

const
  ErrorBufferOverflow* = cstring"Buffer is not large enough"
  ErrorInvalidSequence* = cstring"Invalid Unicode sequence found"
  ErrorInvalidLocale* = cstring"Could not obtain system locale"
  ErrorNotEnoughCharacters* = cstring"Not enough characters in string"

proc utf8Validate*[T: Bytes](data: openarray[T]): bool =
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

proc utf8Length*[T: Bytes](data: openarray[T]): UResult[int] =
  ## Returns number of UTF-8 encoded characters in array ``data``.
  ##
  ## NOTE: Validate data with `utf8Validate()` before using this procedure,
  ## otherwise length returned by this procedure could be incorrect.
  var index = 0
  var size = 0
  while index < len(data):
    let ch = uint(data[index])
    if ch < 0x80:
      inc(index, 1)
    elif (ch and 0xE0'u8) == 0xC0'u8:
      inc(index, 2)
    elif (ch and 0xF0'u8) == 0xE0'u8:
      inc(index, 3)
    elif (ch and 0xF8'u8) == 0xF0'u8:
      inc(index, 4)
    else:
      return err(ErrorInvalidSequence)
    inc(size)
  if index == len(data):
    ok(size)
  else:
    err(ErrorInvalidSequence)

proc utf8Offset*[T: Bytes](data: openarray[T], index: int): UResult[int] =
  ## Return offset in UTF-8 encoded string ``data`` for character position
  ## ``index``.
  if index <= 0:
    return ok(0)

  var byteIndex = 0
  var charIndex = 0

  while (byteIndex < len(data)) and (charIndex < index):
    let ch = uint(data[byteIndex])
    if ch < 0x80:
      inc(byteIndex, 1)
    elif (ch and 0xE0'u8) == 0xC0'u8:
      inc(byteIndex, 2)
    elif (ch and 0xF0'u8) == 0xE0'u8:
      inc(byteIndex, 3)
    elif (ch and 0xF8'u8) == 0xF0'u8:
      inc(byteIndex, 4)
    else:
      return err(ErrorInvalidSequence)
    inc(charIndex)

  if charIndex == index:
    ok(byteIndex)
  else:
    err(ErrorNotEnoughCharacters)

proc utf8Substr*[T: Bytes](data: openarray[T],
                           start, finish: int): UResult[string] =
  ## Substring string ``data`` using starting character (not byte) index
  ## ``start`` and terminating character (not byte) index ``finish`` and return
  ## result string.
  ##
  ## ``data`` should be correct UTF-8 encoded string, because only initial
  ## octets got validated.
  ##
  ## ``start`` - The starting index of the substring, any value BELOW or EQUAL
  ## to zero will be considered as zero. If ``start`` index is not present in
  ## string ``data`` empty string will be returned as result.
  ##
  ## ``finish`` - The terminating index of the substring, any value BELOW
  ## zero will be considered as `len(data)`.
  let soffset =
    if start <= 0:
      0
    elif start >= len(data):
      return ok("")
    else:
      let res = utf8Offset(data, start)
      if res.isErr():
        if res.error != ErrorNotEnoughCharacters:
          return err(res.error)
        return ok("")
      else:
        res.get()

  let eoffset =
    if finish < 0:
      len(data)
    elif finish >= len(data):
      len(data)
    else:
      let res = utf8Offset(data, finish + 1)
      if res.isErr():
        if res.error != ErrorNotEnoughCharacters:
          return err(res.error)
        len(data)
      else:
        res.get()

  var res = newString(eoffset - soffset)
  var k = 0
  for i in soffset ..< eoffset:
    res[k] = cast[char](data[i])
    inc(k)
  ok(res)

proc utf32toUtf8*[A: Wides32, B: Bytes](input: openarray[A],
                                      output: var openarray[B]): UResult[int] =
  ## Converts UTF-32 sequence ``input`` to UTF-8 array ``output``.
  var offset = 0
  for item in input:
    let codepoint =
      block:
        if (uint32(item) >= 0xD800'u32) and (uint32(item) <= 0xDFFF'u32):
          # high and low surrogates U+D800 through U+DFFF prohibited in UTF-32.
          return err(ErrorInvalidSequence)
        elif (uint32(item) == 0xFFFE'u32) or (uint32(item) == 0xFFFF'u32):
          # these codes are intended for process-internal uses, and not a
          # unicode characters.
          return err(ErrorInvalidSequence)
        uint32(item)
    if codepoint <= 0x7F'u32:
      if len(output) > 0:
        if offset < len(output):
          output[offset] = cast[B](codepoint and 0x7F'u32)
        else:
          return err(ErrorBufferOverflow)
      inc(offset, 1)
    elif codepoint <= 0x7FF'u32:
      if len(output) > 0:
        if offset + 1 < len(output):
          output[offset + 0] = cast[B](0xC0'u8 or
                                       byte((codepoint shr 6) and 0x1F'u32))
          output[offset + 1] = cast[B](0x80'u8 or byte(codepoint and 0x3F'u32))
        else:
          return err(ErrorBufferOverflow)
      inc(offset, 2)
    elif codepoint <= 0xFFFF'u32:
      if len(output) > 0:
        if offset + 2 < len(output):
          output[offset + 0] = cast[B](0xE0'u8 or
                                       byte((codepoint shr 12) and 0x0F'u32))
          output[offset + 1] = cast[B](0x80'u8 or
                                       byte((codepoint shr 6) and 0x3F'u32))
          output[offset + 2] = cast[B](0x80'u8 or byte(codepoint and 0x3F'u32))
        else:
          return err(ErrorBufferOverflow)
      inc(offset, 3)
    elif codepoint <= 0x10FFFF'u32:
      if len(output) > 0:
        if offset + 3 < len(output):
          output[offset + 0] = cast[B](0xF0'u8 or
                                       byte((codepoint shr 18) and 0x07'u32))
          output[offset + 1] = cast[B](0x80'u8 or
                                       byte((codepoint shr 12) and 0x3F'u32))
          output[offset + 2] = cast[B](0x80'u8 or
                                       byte((codepoint shr 6) and 0x3F'u32))
          output[offset + 3] = cast[B](0x80'u8 or byte(codepoint and 0x3F'u32))
        else:
          return err(ErrorBufferOverflow)
      inc(offset, 4)
    else:
      return err(ErrorInvalidSequence)
  ok(offset)

proc utf32toUtf8*[T: Wides32](input: openarray[T]): UResult[string] {.inline.} =
  ## Converts wide character sequence ``input`` to UTF-8 encoded string.
  var empty: array[0, char]
  let size = ? utf32ToUtf8(input, empty)
  var output = newString(size)
  let res {.used.} = ? utf32ToUtf8(input, output)
  ok(output)

proc utf8toUtf32*[A: Bytes, B: Wides32](input: openarray[A],
                                       output: var openarray[B]): UResult[int] =
  ## Convert UTF-8 encoded array of characters ``input`` to UTF-32 encoded
  ## sequences of 32bit limbs.
  ##
  ## To obtain required size of ``output`` you need to pass ``output`` as
  ## zero-length array, in such way required size will be returned as result of
  ## procedure.
  ##
  ## If size of ``output`` is not zero, and there not enough space in ``output``
  ## array to store whole ``input`` array, error ``ErrorBufferOverflow`` will
  ## be returned.
  var index = 0
  var dindex = 0
  if len(output) == 0:
    return utf8Length(input)
  else:
    while true:
      if index >= len(input):
        break
      let byte1 = uint32(input[index])
      inc(index)

      if (byte1 and 0x80) == 0x00:
        if dindex < len(output):
          output[dindex] = B(byte1)
          inc(dindex)
        else:
          return err(ErrorBufferOverflow)
      elif (byte1 and 0xE0'u32) == 0xC0'u32:
        # Two-byte form (110xxxxx 10xxxxxx)
        if index >= len(input):
          return err(ErrorInvalidSequence)
        # overlong sequence test
        if (byte1 and 0xFE'u32) == 0xC0'u32:
          return err(ErrorInvalidSequence)

        let byte2 = uint32(input[index])
        if (byte2 and 0xC0'u32) != 0x80'u32:
          return err(ErrorInvalidSequence)

        if dindex < len(output):
          output[dindex] = B(((byte1 and 0x1F'u32) shl 6) or
                              (byte2 and 0x3F'u32))
          inc(dindex)
        else:
          return err(ErrorBufferOverflow)
        inc(index)
      elif (byte1 and 0xF0'u32) == 0xE0'u32:
        # Three-byte form (1110xxxx 10xxxxxx 10xxxxxx)
        if (index + 1) >= len(input):
          return err(ErrorInvalidSequence)

        let byte2 = uint32(input[index])
        if (byte2 and 0xC0'u32) != 0x80'u32:
          return err(ErrorInvalidSequence)
        # overlong sequence test
        if (byte1 == 0xE0'u32) and ((byte2 and 0xE0'u32) == 0x80'u32):
          return err(ErrorInvalidSequence)
        #  0xD800–0xDFFF (UTF-16 surrogates) test
        if (byte1 == 0xED'u32) and ((byte2 and 0xE0'u32) == 0xA0'u32):
          return err(ErrorInvalidSequence)

        let byte3 = uint32(input[index + 1])
        if (byte3 and 0xC0'u32) != 0x80'u32:
          return err(ErrorInvalidSequence)
        # U+FFFE or U+FFFF test
        if (byte1 == 0xEF'u32) and (byte2 == 0xBF'u32) and
           ((byte3 and 0xFE'u32) == 0xBE'u32):
          return err(ErrorInvalidSequence)

        if dindex < len(output):
          output[dindex] = B(((byte1 and 0x0F'u32) shl 12) or
                             ((byte2 and 0x3F'u32) shl 6) or
                              (byte3 and 0x3F'u32))
          inc(dindex)
        else:
          return err(ErrorBufferOverflow)
        inc(index, 2)

      elif (byte1 and 0xF8'u8) == 0xF0'u8:
        # Four-byte form (11110xxx 10xxxxxx 10xxxxxx 10xxxxxx)
        if (index + 2) >= len(input):
          return err(ErrorInvalidSequence)

        let byte2 = uint32(input[index])
        if (byte2 and 0xC0'u32) != 0x80'u32:
          return err(ErrorInvalidSequence)
        # overlong sequence test
        if (byte1 == 0xF0'u32) and ((byte2 and 0xF0'u32) == 0x80'u32):
          return err(ErrorInvalidSequence)
        # According to RFC 3629 no point above U+10FFFF should be used, which
        # limits characters to four bytes.
        if ((byte1 == 0xF4'u32) and (byte2 > 0x8F'u32)) or (byte1 > 0xF4'u32):
          return err(ErrorInvalidSequence)

        let byte3 = uint32(input[index + 1])
        if (byte3 and 0xC0'u32) != 0x80'u32:
          return err(ErrorInvalidSequence)

        let byte4 = uint32(input[index + 2])
        if (byte4 and 0xC0'u32) != 0x80'u32:
          return err(ErrorInvalidSequence)

        if dindex < len(output):
          output[dindex] = B(((byte1 and 0x07'u32) shl 18) or
                             ((byte2 and 0x3F'u32) shl 12) or
                             ((byte3 and 0x3F'u32) shl 6) or
                              (byte4 and 0x3F'u32))
          inc(dindex)
        else:
          return err(ErrorBufferOverflow)
        inc(index, 3)

      else:
        return err(ErrorInvalidSequence)

    ok(dindex)

proc utf8toUtf32*[A: Bytes, B: Wides32](et: typedesc[B],
                                        input: openarray[A]): UResult[seq[B]] =
  ## Convert UTF-8 encoded array of characters ``input`` to UTF-32 encoded
  ## sequence of 32bit limbs and return it.
  var empty: array[0, B]
  let size = ? utf8toUtf32(input, empty)
  var output = newSeq[B](size)
  let res {.used.} = ? utf8toUtf32(input, output)
  ok(output)

when defined(posix):
  import posix

  type
    Mbstate {.importc: "mbstate_t",
              header: "<wchar.h>", pure, final.} = object

  proc mbsrtowcs(dest: pointer, src: pointer, n: csize_t,
                 ps: ptr Mbstate): csize_t {.
       importc, header: "<wchar.h>".}

  proc mbstowcs*[A: Bytes, B: Wides](t: typedesc[B],
                                     input: openarray[A]): UResult[seq[B]] =
    ## Converts multibyte encoded string to OS specific wide char string.
    ##
    ## Note, that `input` should be `0` terminated.
    ##
    ## Encoding is made using `mbsrtowcs`, so procedure supports invalid
    ## sequences and able to decoded all the characters before first invalid
    ## character encountered.

    # Without explicitely setting locale because `mbsrtowcs` will fail with
    # EILSEQ.
    # If locale is an empty string, "", each part of the locale that should
    # be modified is set according to the environment variables.
    let sres = setlocale(LC_ALL, cstring"")
    if isNil(sres):
      return err(ErrorInvalidLocale)

    var buffer = newSeq[B](len(input))
    if len(input) == 0:
      return ok(buffer)

    doAssert(input[^1] == A(0), "Input array should be zero-terminated")
    var data = @input
    var ostr = addr data[0]
    var pstr = ostr
    var mstate = Mbstate()

    while true:
      let res = mbsrtowcs(addr buffer[0], addr pstr, csize_t(len(buffer)),
                          addr mstate)
      if res == cast[csize_t](-1):
        # If invalid multibyte sequence has been encountered, ``pstr`` is left
        ## pointing to the invalid multibyte sequence, ``-1`` is returned, and
        ## errno is set to EILSEQ.
        let diff = cast[uint](pstr) - cast[uint](ostr)
        if diff == 0:
          return err(ErrorInvalidSequence)
        else:
          # We have partially decoded sequence, `diff` is position of first
          # invalid character in sequence.
          data[diff] = A(0x00)
          ostr = addr data[0]
          pstr = ostr
          mstate = Mbstate()
      else:
        # Its safe to convert `csize_t` to `int` here because `len(input)`
        # is also `int`.
        buffer.setLen(res)
        return ok(buffer)
