import
  unittest,
  ../stew/bitseqs

suite "Bit fields":
  test "roundtrips":
    var
      a = BitSeq.init(100)
      b = BitSeq.init(100)

    check:
      not a[0]

    a.raiseBit 1

    check:
      not a[0]
      a[1]

    b.raiseBit 2

    a.combine(b)

    check:
      not a[0]
      a[1]
      a[2]
