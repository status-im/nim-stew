import
  std/[hashes, typetraits]

func hashAllFields*(x: object|tuple): Hash =
  mixin hash
  for f in fields(x):
    result = result !& hash(f)
  result = !$result

export hashes
