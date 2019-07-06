import
  random, unittest,
  ../../stew/ranges/bitranges

proc randomBytes(n: int): seq[byte] =
  result = newSeq[byte](n)
  for i in 0 ..< result.len:
    result[i] = byte(rand(256))

suite "bit ranges":

  test "basic":
    var a = @[byte 0b10101010, 0b11110000, 0b00001111, 0b01010101]

    var bSeq = @[byte 0b10101010, 0b00000000, 0b00000000, 0b11111111]
    var b = bits(bSeq, 8)

    var cSeq = @[byte 0b11110000, 0b00001111, 0b00000000, 0b00000000]
    var c = bits(cSeq, 16)

    var dSeq = @[byte 0b00001111, 0b00000000, 0b00000000, 0b00000000]
    var d = bits(dSeq, 8)

    var eSeq = @[byte 0b01010101, 0b00000000, 0b00000000, 0b00000000]
    var e = bits(eSeq, 8)

    var m = a.bits
    var n = m[0..7]
    check n == b
    check n.len == 8
    check b.len == 8
    check c == m[8..23]
    check $(d) == "00001111"
    check $(e) == "01010101"

    var f = int.fromBits(e, 0, 4)
    check f == 0b0101

    let k = n & d
    check(k.len == n.len + d.len)
    check($k == $n & $d)

    var asciiSeq = @[byte('A'),byte('S'),byte('C'),byte('I'),byte('I')]
    let asciiBits = bits(asciiSeq)
    check $asciiBits == "0100000101010011010000110100100101001001"

  test "concat operator":
    randomize(5000)

    for i in 0..<256:
      var xSeq = randomBytes(rand(i))
      var ySeq = randomBytes(rand(i))
      let x = xSeq.bits
      let y = ySeq.bits
      var z = x & y
      check z.len == x.len + y.len
      check($z == $x & $y)

  test "get set bits":
    randomize(1000)

    for i in 0..<256:
      # produce random vector
      var xSeq = randomBytes(i)
      var ySeq = randomBytes(i)
      var x = xSeq.bits
      var y = ySeq.bits
      for idx, bit in x:
        y[idx] = bit
      check x == y

  test "constructor with start":
    var a = @[byte 0b10101010, 0b11110000, 0b00001111, 0b01010101]
    var b = a.bits(1, 8)
    check b.len == 8
    check b[0] == false
    check $b == "01010101"
    b[0] = true
    check $b == "11010101"
    check b[0] == true
    b.pushFront(false)
    check b[0] == false
    check $b == "011010101"
