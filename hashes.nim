import
  ./results,
  ./keccak,
  ./writer
export results, writer
type Hash32* = distinct array[32, byte]
template data*(v: Hash32): array[32, byte] =
  array[32, byte](v)
template to*(v: MDigest[256], _: type Hash32): Hash32 =
  Hash32(v.data)
func keccak256*(input: openArray[byte]): Hash32 =
  var ctx: KeccakContext[256]
  ctx.update(input)
  ctx.finish().to(Hash32)
