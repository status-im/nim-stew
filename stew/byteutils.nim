# byteutils
# Copyright (c) 2018-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.


########################################################################################################
####################################   Array utilities   ###############################################

import
  std/[algorithm, typetraits],
  ./arrayops

# backwards compat
export arrayops.`&`, arrayops.initArrayWith, arrayops.`[]=`

when (NimMajor, NimMinor) < (1, 4):
  {.push raises: [Defect].}
  {.pragma: hexRaises, raises: [Defect, ValueError].}
else:
  {.push raises: [].}
  {.pragma: hexRaises, raises: [ValueError].}

########################################################################################################
#####################################   Hex utilities   ################################################

proc readHexChar*(c: char): byte
                 {.hexRaises, noSideEffect, inline.} =
  ## Converts an hex char to a byte
  case c
  of '0'..'9': result = byte(ord(c) - ord('0'))
  of 'a'..'f': result = byte(ord(c) - ord('a') + 10)
  of 'A'..'F': result = byte(ord(c) - ord('A') + 10)
  else:
    raise newException(ValueError, $c & " is not a hexadecimal character")

template skip0xPrefix(hexStr: openArray[char]): int =
  ## Returns the index of the first meaningful char in `hexStr` by skipping
  ## "0x" prefix
  if hexStr.len > 1 and hexStr[0] == '0' and hexStr[1] in {'x', 'X'}: 2
  else: 0

func hexToByteArrayImpl(
    hexStr: openArray[char], output: var openArray[byte], fromIdx, toIdx: int):
    int {.hexRaises.} =
  var sIdx = skip0xPrefix(hexStr)
  # Fun with closed intervals
  doAssert fromIdx >= 0 and
    toIdx <= output.high and
    fromIdx <= (toIdx + 1)

  let sz = toIdx + 1 - fromIdx

  if hexStr.len - sIdx < 2*sz:
    raise (ref ValueError)(msg: "hex string too short")

  sIdx += fromIdx * 2
  for bIdx in fromIdx ..< sz + fromIdx:
    output[bIdx] =
      (hexStr[sIdx].readHexChar shl 4) or
      hexStr[sIdx + 1].readHexChar
    inc(sIdx, 2)

  sIdx

func hexToByteArray*(
    hexStr: openArray[char], output: var openArray[byte], fromIdx, toIdx: int)
    {.hexRaises.} =
  ## Read hex-encoded data from `hexStr[mapHex(fromIdx..toIdx)]` and store
  ## corresponding bytes in `output[fromIdx..toIdx]` where `mapHex` takes into
  ## account stripped characters.
  ##
  ## * `0x`/`0X` is stripped if present
  ## * `ValueError` is raised if the string is too short or contains invalid
  ##   data in the parsed part
  ## * Longer strings are allowed
  ## * No "endianness" reordering is done
  ## * Allows specifying the byte range to process into the array - the indices
  ##   are mapped to the string after potentially stripping "0x"
  discard hexToByteArrayImpl(hexStr, output, fromIdx, toIdx)

func hexToByteArray*(hexStr: openArray[char], output: var openArray[byte])
                    {.hexRaises.} =
  ## Read hex-encoded data from `hexStr` and store corresponding bytes in
  ## `output`.
  ##
  ## * `0x`/`0X` is stripped if present
  ## * `ValueError` is raised if the string is too short or contains invalid
  ##   data
  ## * Longer strings are allowed
  ## * No "endianness" reordering is done
  hexToByteArray(hexStr, output, 0, output.high)

func hexToByteArray*[N: static[int]](hexStr: openArray[char]): array[N, byte]
                    {.hexRaises, noinit.}=
  ## Read hex-encoded data from `hexStr` returning an array of N bytes.
  ##
  ## * `0x`/`0X` is stripped if present
  ## * `ValueError` is raised if the string is too short or contains invalid
  ##   data
  ## * Longer strings are allowed
  ## * No "endianness" reordering is done
  hexToByteArray(hexStr, result)

func hexToByteArray*(hexStr: openArray[char], N: static int): array[N, byte]
                    {.hexRaises, noinit.}=
  ## Read hex-encoded data from `hexStr` returning an array of N bytes.
  ##
  ## * `0x`/`0X` is stripped if present
  ## * `ValueError` is raised if the string is too short or contains invalid
  ##   data
  ## * Longer strings are allowed
  ## * No "endianness" reordering is done
  hexToByteArray(hexStr, result)

func hexToByteArrayStrict*(hexStr: openArray[char], output: var openArray[byte])
                          {.hexRaises.} =
  ## Read hex-encoded data from `hexStr` and store corresponding bytes in
  ## `output`.
  ##
  ## * `0x`/`0X` is stripped if present
  ## * `ValueError` is raised if the string is too short, too long or contains
  ##   invalid data
  ## * No "endianness" reordering is done
  if hexToByteArrayImpl(hexStr, output, 0, output.high) != hexStr.len:
    raise (ref ValueError)(msg: "hex string too long")

func hexToByteArrayStrict*[N: static[int]](hexStr: openArray[char]): array[N, byte]
                          {.hexRaises, noinit, inline.}=
  ## Read hex-encoded data from `hexStr` and store corresponding bytes in
  ## `output`.
  ##
  ## * `0x`/`0X` is stripped if present
  ## * `ValueError` is raised if the string is too short, too long or contains
  ##   invalid data
  ## * No "endianness" reordering is done
  hexToByteArrayStrict(hexStr, result)

func hexToByteArrayStrict*(hexStr: openArray[char], N: static int): array[N, byte]
                          {.hexRaises, noinit, inline.}=
  ## Read hex-encoded data from `hexStr` and store corresponding bytes in
  ## `output`.
  ##
  ## * `0x`/`0X` is stripped if present
  ## * `ValueError` is raised if the string is too short, too long or contains
  ##   invalid data
  ## * No "endianness" reordering is done
  hexToByteArrayStrict(hexStr, result)

func fromHex*[N](A: type array[N, byte], hexStr: string): A
             {.hexRaises, noinit, inline.}=
  ## Read hex-encoded data from `hexStr` returning an array of N bytes.
  ##
  ## * `0x`/`0X` is stripped if present
  ## * `ValueError` is raised if the string is too short or contains invalid
  ##   data
  ## * Longer strings are allowed
  ## * No "endianness" reordering is done
  hexToByteArray(hexStr, result)

func hexToPaddedByteArray*[N: static[int]](hexStr: string): array[N, byte]
                          {.hexRaises.} =
  ## Read a hex string and store it in a byte array `output`.
  ## The string may be shorter than the byte array.
  ## No "endianness" reordering is done.
  let
    p = skip0xPrefix(hexStr)
    sz = hexStr.len - p
    maxStrSize = result.len * 2
  var
    bIdx: int
    shift = 4

  if hexStr.len - p > maxStrSize:
    # TODO this is a bit strange, compared to the hexToByteArray above...
    raise (ref ValueError)(msg: "hex string too long")

  if sz < maxStrSize:
    # include extra byte if odd length
    bIdx = result.len - (sz + 1) div 2
    # start with shl of 4 if length is even
    shift = 4 - sz mod 2 * 4

  for sIdx in p ..< hexStr.len:
    let nibble = hexStr[sIdx].readHexChar shl shift
    result[bIdx] = result[bIdx] or nibble
    shift = shift + 4 and 4
    bIdx += shift shr 2

func hexToSeqByte*(hexStr: string): seq[byte]
                  {.hexRaises.} =
  ## Read an hex string and store it in a sequence of bytes. No "endianness" reordering is done.
  if (hexStr.len and 1) == 1:
    raise (ref ValueError)(msg: "hex string must have even length")

  let skip = skip0xPrefix(hexStr)
  let N = (hexStr.len - skip) div 2

  result = newSeq[byte](N)
  for i in 0 ..< N:
    result[i] = hexStr[2*i + skip].readHexChar shl 4 or hexStr[2*i + 1 + skip].readHexChar

func toHexAux(ba: openArray[byte], with0x: static bool): string =
  ## Convert a byte-array to its hex representation
  ## Output is in lowercase
  ## No "endianness" reordering is done.
  const hexChars = "0123456789abcdef"

  let extra = when with0x: 2 else: 0
  result = newStringOfCap(2 * ba.len + extra)
  when with0x:
    result.add("0x")

  for b in ba:
    result.add(hexChars[int(b shr 4 and 0x0f'u8)])
    result.add(hexChars[int(b and 0x0f'u8)])

func toHex*(ba: openArray[byte]): string {.inline.} =
  ## Convert a byte-array to its hex representation
  ## Output is in lowercase
  ## No "endianness" reordering is done.
  toHexAux(ba, false)

func toHex*[N: static[int]](ba: array[N, byte]): string {.inline.} =
  ## Convert a big endian byte-array to its hex representation
  ## Output is in lowercase
  ## No "endianness" reordering is done.
  toHexAux(ba, false)

func to0xHex*(ba: openArray[byte]): string {.inline.} =
  ## Convert a byte-array to its hex representation
  ## Output is in lowercase
  ## No "endianness" reordering is done.
  toHexAux(ba, true)

func to0xHex*[N: static[int]](ba: array[N, byte]): string {.inline.} =
  ## Convert a big endian byte-array to its hex representation
  ## Output is in lowercase
  ## No "endianness" reordering is done.
  toHexAux(ba, true)

func toBytes*(s: string): seq[byte] =
  ## Convert a string to the corresponding byte sequence - since strings in
  ## nim essentially are byte sequences without any particular encoding, this
  ## simply copies the bytes without a null terminator
  when nimvm:
    var r = newSeq[byte](s.len)
    for i, c in s:
      r[i] = cast[byte](c)
    r
  else:
    @(s.toOpenArrayByte(0, s.high))

func fromBytes*(T: type string, v: openArray[byte]): string =
  if v.len > 0:
    result = newString(v.len)
    when nimvm:
      for i, c in v:
        result[i] = cast[char](c)
    else:
      copyMem(addr result[0], unsafeAddr v[0], v.len)

func `<`*(a, b: openArray[byte]): bool =
  ## Lexicographical compare of two byte arrays
  let minlen = min(a.len, b.len)

  for i in 0..<minlen:
    if a[i] != b[i]: return a[i] < b[i]

  a.len < b.len
