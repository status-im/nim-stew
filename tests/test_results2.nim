import ../stew/results

{.used.}

# Oddly, this piece of code works when placed in `test_results.nim`

template repeater(b: Opt[int]): untyped =
  b
let x = repeater(Opt.none(int))
doAssert x.isNone()
