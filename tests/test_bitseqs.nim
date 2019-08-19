import
  unittest, strformat,
  ../stew/[bitseqs, bitops2]

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

  test "iterating words":
    for bitCount in [8, 3, 7, 8, 14, 15, 16, 19, 260]:
      checkpoint &"trying bit count {bitCount}"
      var
        a = BitSeq.init(bitCount)
        b = BitSeq.init(bitCount)
        bitsInWord = sizeof(uint) * 8
        expectedWordCount = (bitCount div bitsInWord) + 1

      for i in 0 ..< expectedWordCount:
        let every3rdBit = i * sizeof(uint) * 8 + 2
        a[every3rdBit] = true
        b[every3rdBit] = true

      for word in words(a):
        check word == 4
        word = 2

      for wa, wb in words(a, b):
        check wa == 2 and wb == 4
        wa = 1
        wb = 2

      for i in 0 ..< expectedWordCount:
        for j in 0 ..< bitsInWord:
          let bitPos = i * bitsInWord + j
          if bitPos < bitCount:
            check a[j] == (j == 0)
            check b[j] == (j == 1)

  test "overlaps":
    for bitCount in [63, 62]:
      checkpoint &"trying bit count {bitCount}"
      var
        a = BitSeq.init(bitCount)
        b = BitSeq.init(bitCount)
      a.raiseBit(4)
      b.raiseBit(5)

      check:
        not a.overlaps(b)
        not b.overlaps(a)
