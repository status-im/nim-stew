import unittest2
import ../stew/base36
import  ../stew/byteutils

func fromHex(a: string): seq[byte] =
  doAssert(len(a) %% 2 == 0)
  var hex: seq[byte]
  if len(a) == 0:
    hex = newSeq[byte]()
  else:
    hex = newSeq[byte](len(a) div 2)
    hex = hexToSeqByte(a)
  return hex

const TestVectors = [
  ["", "k"],
  ["0001", "k01"],
  ["0000ff", "k0073"],
  ["61", "k2p"],
  ["626262", "k3u736"],
  ["636363", "k3vlur"],
  ["73696d706c792061206c6f6e6720737472696e67", "kdhbvo69kp5joh9co6f1lm8zq4bpp5rb"],
  ["aaeb15231dfceb60925886b67d065299925915aeb172c06647", "k7s4kro2wr10fsld6o2284s1a5w45h4f0yk63ryf"],
  ["516b6fcd0f", "k4gnba1hr"],
  ["bf4f89001e670274dd", "kkos4yabkyy7fml"],
  ["572e4794", "ko6tok4"],
  ["ecac89cad93923c02321", "k520229tco195fokh"],
  ["10c8511e", "k4nmvq6"],
  ["672a39cf0b8be9483302b26413b1784c159b357fafba", "kgxduar7o4l1hyevbs8p62izfwct9q6n3ju"],
  ["000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff", "k0168swoi6iuzj4fbwknlnh695zl88v65qcfgnwrwepqcxb9dysmluowqahvt3r9gsc1v47ssxdivjda3nttl6r044pzz7zwhtgu2mkow5ts28x2mbwenh3wfz4s1sarspfhlrakvqrgpmzb66sgtz2lzbotl7r28wcq8925c747b44l60vrk3scrin4zvnwn7pdsukgo6lgjhu1nuwj7yt1h9ujpe3os17onsk7sp4ysmytu568do2tqetwnrmbxb2dtd8kqorcoakaizlm9svr8axe1acxfursz11nubrhighfd64yhmp99ucvzr944n8co01o4x64cmbd8be0hqbm2zy5uwe4uplc4sa50xajel4bkkxb1kh21pisna37eqwpbpq11ypr"]
]

suite "Base36 encoding test suite":
  test "Empty seq/string test":
    var a = Base36.encode([])
    check len(a) == 1 # only 'k' in output
    var b = Base36.decode("k")
    check len(b) == 0
  test "Leading zero test":
    var buffer: array[256, byte]
    for i in 0..255:
      buffer[255] = byte(i)
      var a = Base36.encode(buffer)
      var b = Base36.decode(a)
      check:
        equalMem(addr buffer[0], addr b[0], 256) == true
  test "Small amount of bytes test":
    var buffer1: array[1, byte]
    var buffer2: array[2, byte]
    for i in 0..255:
      buffer1[0] = byte(i)
      var enc = Base36.encode(buffer1)
      var dec = Base36.decode(enc)
      check:
        len(dec) == 1
        dec[0] == buffer1[0]

    for i in 0..255:
      for k in 0..255:
        buffer2[0] = byte(i)
        buffer2[1] = byte(k)
        var enc = Base36.encode(buffer2)
        var dec = Base36.decode(enc)
        check:
          len(dec) == 2
          dec[0] == buffer2[0]
          dec[1] == buffer2[1]
  test "Test Vectors test":
    for item in TestVectors:
      var a = fromHex(item[0])
      var enc = Base36.encode(a)
      var dec = Base36.decode(item[1])
      check:
        enc == item[1]
        dec == a
  test "Buffer Overrun test":
    var encres = ""
    var encsize = 0
    var decres: seq[byte] = @[]
    var decsize = 0
    check:
      Base36.encode([0'u8], encres, encsize) == Base36Status.Overrun
      encsize == 2
      Base36.decode("k1", decres, decsize) == Base36Status.Overrun
      decsize == 5
  test "Incorrect test":
    var decres = newSeq[byte](10)
    var decsize = 0
    check:
      Base36.decode("=", decres, decsize) == Base36Status.Incorrect
      decsize == 0
      Base36.decode("@", decres, decsize) == Base36Status.Incorrect
      decsize == 0
      Base36.decode("g&", decres, decsize) == Base36Status.Incorrect
      decsize == 0
      Base36.decode("10%", decres, decsize) == Base36Status.Incorrect
      decsize == 0
