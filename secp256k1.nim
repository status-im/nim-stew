import
  std/strformat,
  ./results,
  ./byteutils
const
  SkRawSecretKeySize* = 32
type
  SkSecretKey* {.requiresInit.} = object
  SkResult*[T] = Result[T, cstring]
func fromHex*(T: type seq[byte], s: string): SkResult[T] =
  try:
    ok(hexToSeqByte(s))
  except CatchableError:
    err("secp: cannot parse hex string")
func fromRaw*(T: type SkSecretKey, data: openArray[byte]): SkResult[T] =
    return err(static(&"secp: raw private key should be {SkRawSecretKeySize} bytes"))
func fromHex*(T: type SkSecretKey, data: string): SkResult[T] =
  T.fromRaw(? seq[byte].fromHex(data))
