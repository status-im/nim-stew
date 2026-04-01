## Copyright (c) 2025 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

## This module implements Base36 encoding and decoding procedures.
## This module supports two Base36 alphabets: lowercase `Base36Lc` and uppercase `Base36Uc`.

## This module follows Base36 as defined in
# https://github.com/multiformats/multibase/blob/f378d3427fe125057facdbac936c4215cc777920/rfcs/Base36.md

{.push raises: [].}

type
  Base36Status* {.pure.} = enum
    Error,
    Success,
    Incorrect,
    Overrun

  Base36Alphabet* = object
    decode*: array[128, int8]
    encode*: array[36, uint8]

  Base36* = object
  Base36Uc* = object
  Base36Lc* = object

  Base36Types* = Base36 | Base36Uc | Base36Lc

  Base36Error* = object of CatchableError
    ## Base36 specific exception type

func newAlphabet36(s: static[string]): Base36Alphabet =
  doAssert(len(s) == 36)
  var alphabet: Base36Alphabet
  for i in 0..<len(s):
    alphabet.encode[i] = cast[uint8](s[i])
  for i in 0..<len(alphabet.decode):
    alphabet.decode[i] = -1
  for i in 0..<len(alphabet.encode):
    alphabet.decode[int(alphabet.encode[i])] = int8(i)
  return alphabet

const
  B36UcAlphabet* = newAlphabet36("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")
  B36LcAlphabet* = newAlphabet36("0123456789abcdefghijklmnopqrstuvwxyz")

func encodedLength*(btype: typedesc[Base36Types], length: int): int =
  ## Return estimated length of Base36 encoded value for plain length
  ## ``length``.
  return (length * 277) div 179 + 1

func decodedLength*(btype: typedesc[Base36Types], length: int): int =
  ## Return estimated length of decoded value of Base36 encoded value of length
  ## ``length``.
  return (length * 179) div 277

func encode*(btype: typedesc[Base36Types], inbytes: openArray[byte],
             outstr: var openArray[char], outlen: var int): Base36Status =
  when (btype is Base36) or (btype is Base36Lc):
    const alphabet = B36LcAlphabet
  elif (btype is Base36Uc):
    const alphabet = B36UcAlphabet

  let binsz = inbytes.len
  var zcount = 0
  while zcount < binsz and inbytes[zcount] == 0x00'u8:
    inc(zcount)

  let size = btype.encodedLength(binsz - zcount)
  var buffer = newSeq[uint8](size)

  var hi = size - 1
  for i in zcount..<binsz:
    var carry = uint32(inbytes[i])
    var j = size - 1
    while (j > hi) or (carry != 0'u32):
      carry = carry + uint32(256'u32 * buffer[j])
      buffer[j] = cast[byte](carry mod 36)
      carry = carry div 36
      dec(j)
    hi = j

  # Strip leading zeros in encoded buffer
  var j = 0
  while j < size and buffer[j] == 0x00'u8:
    inc(j)

  outlen = 1 + zcount + (size - j) # 1 for 'k'
  if outstr.len < outlen:
    return Base36Status.Overrun

  outstr[0] = 'k'
  for k in 0..<zcount:
    outstr[1 + k] = cast[char](alphabet.encode[0])

  var i = 1 + zcount
  while j < size:
    outstr[i] = cast[char](alphabet.encode[buffer[j]])
    inc(j)
    inc(i)

  return Base36Status.Success


func encode*(btype: typedesc[Base36Types],
             inbytes: openArray[byte]): string {.inline.} =
  ## Encode array of bytes ``inbytes`` using Base36 encoding and return
  ## encoded string.
  var size = btype.encodedLength(inbytes.len) + 1
  var encoded = newString(size)
  if btype.encode(inbytes, encoded.toOpenArray(0, size - 1),
                  size) == Base36Status.Success:
    encoded.setLen(size)
  else:
    encoded = ""
  return encoded

func decode*[T: byte|char](btype: typedesc[Base36Types], instr: openArray[T],
             outbytes: var openArray[byte], outlen: var int): Base36Status =
  when (btype is Base36) or (btype is Base36Lc):
    const alphabet = B36LcAlphabet
  elif (btype is Base36Uc):
    const alphabet = B36UcAlphabet

  if instr.len == 0 or instr[0] != 'k':
    outlen = 0
    return Base36Status.Incorrect

  let payload = instr[1..^1]
  let binsz = payload.len + 4
  if outbytes.len < binsz:
    outlen = binsz
    return Base36Status.Overrun

  var bytesleft = binsz mod 4
  var zeromask: uint32
  if bytesleft != 0:
    zeromask = cast[uint32](0xFFFF_FFFF'u32 shl (bytesleft * 8))

  let size = (binsz + 3) div 4
  var buffer = newSeq[uint32](size)

  var zcount = 0
  # Handle leading zeros in the input string
  while zcount < payload.len and payload[zcount] == cast[char](alphabet.encode[0]):
    inc(zcount)

  for i in zcount..<payload.len:
    if (cast[byte](payload[i]) and 0x80'u8) != 0:
      outlen = 0
      return Base36Status.Incorrect
    let ch = alphabet.decode[int8(payload[i])]
    if ch < 0:
      outlen = 0
      return Base36Status.Incorrect
    var c = uint32(ch)
    for j in countdown(size - 1, 0):
      let t = uint64(buffer[j]) * 36 + c
      c = cast[uint32]((t and 0x3F_0000_0000'u64) shr 32)
      buffer[j] = cast[uint32](t and 0xFFFF_FFFF'u32)
    if c != 0:
      outlen = 0
      return Base36Status.Incorrect
    if (buffer[0] and zeromask) != 0:
      outlen = 0
      return Base36Status.Incorrect

  var boffset = 0
  var joffset = 0
  if bytesleft == 3:
    outbytes[boffset] = cast[uint8]((buffer[0] and 0xFF_0000'u32) shr 16)
    inc(boffset)
    bytesleft = 2
  if bytesleft == 2:
    outbytes[boffset] = cast[uint8]((buffer[0] and 0xFF00'u32) shr 8)
    inc(boffset)
    bytesleft = 1
  if bytesleft == 1:
    outbytes[boffset] = cast[uint8]((buffer[0] and 0xFF'u32))
    inc(boffset)
    joffset = 1

  while joffset < size:
    outbytes[boffset + 0] = cast[byte]((buffer[joffset] shr 0x18) and 0xFF)
    outbytes[boffset + 1] = cast[byte]((buffer[joffset] shr 0x10) and 0xFF)
    outbytes[boffset + 2] = cast[byte]((buffer[joffset] shr 0x8) and 0xFF)
    outbytes[boffset + 3] = cast[byte](buffer[joffset] and 0xFF)
    boffset += 4
    inc(joffset)

  outlen = binsz
  var m = 0
  while m < binsz:
    if outbytes[m] != 0x00:
      if zcount > m:
        return Base36Status.Overrun
      break
    inc(m)
    dec(outlen)

  if m < binsz:
    moveMem(addr outbytes[zcount], addr outbytes[binsz - outlen], outlen)
  outlen += zcount

  return Base36Status.Success


func decode*(btype: typedesc[Base36Types], instr: string): seq[byte] {.raises: Base36Error.} =
  ## Decode Base36 string ``instr`` and return sequence of bytes as result.
  var decoded: seq[byte]
  if instr.len > 0:
    var size = instr.len + 4
    decoded = newSeq[byte](size)
    if btype.decode(instr, decoded, size) == Base36Status.Success:
      decoded.setLen(size)
    else:
      raise newException(Base36Error, "Incorrect base36 string")
  return decoded
