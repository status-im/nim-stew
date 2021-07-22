## utf
## Copyright (c) 2021 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

# DFA based UTF8 decoder/validator
# See http://bjoern.hoehrmann.de/utf-8/decoder/dfa/ for details.

import stew/ranges/ptr_arith
import stew/results

type
  Utf8*  = object
  Utf16* = object
  Utf32* = object
  Utf*   = uint32

const
  UTF8_ACCEPT* = 0
  UTF8_REJECT* = 12

  highBegin = 0xD800
  highEnd   = 0xDBFF
  lowBegin  = 0xDC00
  lowEnd    = 0xDFFF

  Utf16Shift = 10
  Utf16Base  = 0x0010000
  Utf16Mask  = 0x3FF
  Utf16Maxbmp= 0xFFFF
  MaxUtf     = 0x10FFFF

  DefaultReplacement* = 0xFFFD
  InvalidUTF8  = "invalid UTF-8 sequence"
  InvalidUTF16 = "invalid UTF-16 sequence"
  InvalidUTF32 = "invalid UTF-32 sequence"

const
  utf8Table = [
    # The first part of the table maps bytes to character classes that
    # to reduce the size of the transition table and create bitmasks.
    0'u8,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0   ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0   ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0   ,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    1   ,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,  9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
    7   ,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,  7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
    8   ,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,  2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    10  ,3,3,3,3,3,3,3,3,3,3,3,3,4,3,3, 11,6,6,6,5,8,8,8,8,8,8,8,8,8,8,8,

    # The second part is a transition table that maps a combination
    # of a state of the automaton and a character class to a state.
    0 ,12,24,36,60,96,84,12,12,12,48,72, 12,12,12,12,12,12,12,12,12,12,12,12,
    12, 0,12,12,12,12,12, 0,12, 0,12,12, 12,24,12,12,12,12,12,24,12,24,12,12,
    12,12,12,12,12,12,12,24,12,12,12,12, 12,24,12,12,12,12,12,12,12,24,12,12,
    12,12,12,12,12,12,12,36,12,36,12,12, 12,36,12,12,12,12,12,36,12,36,12,12,
    12,36,12,12,12,12,12,12,12,12,12,12
  ]

proc validate*[T: byte | char](_: type Utf8, text: openArray[T]): bool =
  var state = 0
  for c in text:
    let x = utf8Table[c.int].int
    state = utf8Table[256 + state + x].int
  state == UTF8_ACCEPT

proc count*[T: byte | char](_: type Utf8,
                            text: openArray[T]): Result[int, string] =
  var
    state = 0
    res   = 0
  for c in text:
    let x = utf8Table[c.int].int
    state = utf8Table[256 + state + x].int
    if state == UTF8_ACCEPT:
      inc res
  if state == UTF8_ACCEPT:
    ok(res)
  else:
    err(InvalidUTF8)

proc highSurrogate*(_: type Utf16, c: int): bool =
  c >= highBegin and c <= highEnd

proc lowSurrogate*(_: type Utf16, c: int): bool =
  c >= lowBegin and c <= lowEnd

proc utf*(_: type Utf16, c1, c2: int): Utf =
  Utf(((c1 - highBegin) shl Utf16Shift) + (c2 - lowBegin) + Utf16Base)

proc inc*(_: type Utf16, cp: int, res: var int): bool =
  if cp <= Utf16Maxbmp:
    if cp >= highBegin and cp <= lowBegin:
      return false
    else:
      inc res
  elif cp > MaxUtf:
    return false
  else:
    inc res, 2

  return true

proc utf16Len*[T: byte | char](_: type Utf8,
                               text: openArray[T]): Result[int, string] =
  var
    state = 0
    cp    = 0
    res   = 0
  for c in text:
    let x = utf8Table[c.int].int
    cp = if state != UTF8_ACCEPT:
          (c and 0x3fu) or (cp shl 6)
         else:
          (0xff shr x) and c
    state = utf8Table[256 + state + x].int
    if state == UTF8_ACCEPT:
      if not Utf16.inc(cp, res):
        return err(InvalidUTF8)
  if state == UTF8_ACCEPT:
    ok(res)
  else:
    err(InvalidUTF8)

proc inc*(_: type Utf8, cp: int, res: var int): bool =
  if cp < 0x80:
    inc res
  elif cp < 0x800:
    inc res, 2
  elif cp < 0x10000:
    inc res, 3
  elif cp <= MaxUtf:
    inc res, 4
  else:
    return false
  return true

proc utf8Len*(_: type Utf32, text: openArray[uint32]): Result[int, string] =
  var res = 0
  for cp in text:
    if not Utf8.inc(cp, res):
      return err(InvalidUTF32)
  ok(res)

proc utf16Len*(_: type Utf32, text: openArray[uint32]): Result[int, string] =
  var res = 0
  for cp in text:
    if not Utf16.inc(cp, res):
      return err(InvalidUTF32)
  ok(res)

proc utf8Len*(_: type Utf16, text: openArray[uint16]): Result[int, string] =
  var
    i   = 0
    res = 0
  while i < text.len:
    let c1 = text[i]
    if c1 >= highBegin and c1 <= highEnd:
      inc i
      if i >= text.len:
        return err(InvalidUtf16)
      # surrogate pairs
      let c2 = text[i]
      if c2 < lowBegin or c2 > lowEnd:
        return err(InvalidUtf16)
      let cp = Utf16.utf(c1, c2)
      if not Utf8.inc(cp, res):
        return err(InvalidUtf16)
    elif c1 >= lowBegin and c1 <= lowEnd:
      return err(InvalidUtf16)
    inc i
    if not Utf8.inc(c1, res):
      return err(InvalidUtf16)

  ok(res)

proc validate*(_: type Utf16, text: openArray[uint16]): bool =
  var i  = 0
  while i < text.len:
    let c1 = text[i]
    if c1 >= highBegin and c1 <= highEnd:
      inc i
      if i >= text.len:
        return false
      # surrogate pairs
      let c2 = text[i]
      if c2 < lowBegin or c2 > lowEnd:
        return false
    elif c1 >= lowBegin and c1 <= lowEnd:
      return false
    inc i
  return true

proc validate*[T: byte | char](_: type Utf16, text: openArray[T]): bool =
  if text.len mod 2 != 0:
    return false
  if text.len == 0:
    return true
  Utf16.validate(makeOpenArray(text[0].unsafeAddr, uint16, text.len div 2))

proc append*(_: type Utf8, text: var (string | seq[byte]), cp: int): bool =
  var len = 0
  if not Utf8.inc(cp, len):
    return false
  let pos = text.len
  text.setLen(text.len + len)

  when text is string:
    type T = char
  else:
    type T = byte

  if len == 1:
    text[pos + 0] = T(cp)
  elif len == 2:
    text[pos + 0] = T(0xC0 + (cp shr 6))
    text[pos + 1] = T(0x80 + (cp and 0x3f))
  elif len == 3:
    text[pos + 0] = T(0xE0 + ( cp shr 12))
    text[pos + 1] = T(0x80 + ((cp shr 6) and 0x3F))
    text[pos + 2] = T(0x80 + ( cp and 0x3F))
  else:
    text[pos + 0] = T(0xF0 + ( cp shr 18))
    text[pos + 1] = T(0x80 + ((cp shr 12) and 0x3F))
    text[pos + 2] = T(0x80 + ((cp shr 6)  and 0x3F))
    text[pos + 3] = T(0x80 + ( cp and 0x3F))

  return true

proc append*(_: type Utf8, text: var (string | seq[byte]), c1, c2: int): bool =
  Utf8.append(text, Utf16.utf(c1, c2))

proc append*(_: type Utf16, text: var seq[uint16], cp: int): bool =
  if cp <= Utf16Maxbmp:
    if cp >= highBegin and cp <= lowBegin:
      return false
    else:
      text.add uint16(cp)
  elif cp > MaxUtf:
    return false
  else:
    let c = cp - Utf16Base
    text.add uint16((c shr Utf16Shift) + highBegin)
    text.add uint16((c and Utf16Mask) + lowBegin)

  return true

proc append*[T: byte | char](_: type Utf16,
                             res: var seq[uint16],
                             text: openArray[T]): Result[int, string] =
  let r = Utf8.utf16Len(text)
  if r.isErr:
    return r
  var pos = res.len
  res.setLen(pos + r.get())

  var
    state = 0
    cp    = 0
  for c in text:
    let x = utf8Table[c.int].int
    cp = if state != UTF8_ACCEPT:
          (c and 0x3fu) or (cp shl 6)
         else:
          (0xff shr x) and c
    state = utf8Table[256 + state + x].int
    if state == UTF8_ACCEPT:
      if cp <= Utf16MaxBmp:
        res[pos] = uint16(cp)
        inc pos
      else:
        res[pos + 0] = uint16((cp shr Utf16Shift) + highBegin)
        res[pos + 1] = uint16((cp and Utf16Mask) + lowBegin)
        inc pos, 2

  return r
