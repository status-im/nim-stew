import unittest
import ../stew/ctops

suite "Constant-time operations test suite":
  test "isEqual() test":
    let
      charArr1 = ['T', 'E', 'S', 'T']
      charArr2 = ['A', 'B', 'C', 'D']
      charArr3 = ['B', 'I', 'G', 'M', 'E', 'S', 'S', 'A', 'G', 'E']
      charArr4 = ['T', 'E', 'S', 'T', 'B', 'I', 'G']
      charArr5 = ['B', 'I', 'G', 'T', 'E', 'S', 'T']
      byteArr1 = [0x54'u8, 0x45'u8, 0x53'u8, 0x54'u8]
      byteArr2 = [0x41'u8, 0x42'u8, 0x43'u8, 0x44'u8]
      byteArr3 = [0x42'u8, 0x49'u8, 0x47'u8, 0x4D'u8, 0x45'u8,
                    0x53'u8, 0x53'u8, 0x41'u8, 0x47'u8, 0x45'u8]
      byteArr4 = [0x54'u8, 0x45'u8, 0x53'u8, 0x54'u8, 0x42'u8,
                    0x49'u8, 0x47'u8]
      byteArr5 = [0x42'u8, 0x49'u8, 0x47'u8, 0x54'u8, 0x45'u8,
                    0x53'u8, 0x54'u8]
      str1 = "TEST"
      str2 = "ABCD"
      str3 = "BIGMESSAGE"
      str4 = "TESTBIG"
      str5 = "BIGTEST"
      seq1 = @byteArr1
      seq2 = @byteArr2
      seq3 = @byteArr3
      seq4 = @byteArr4
      seq5 = @byteArr5

    check:
      CT.isEqual(charArr1, charArr1) == true
      CT.isEqual(charArr1, byteArr1) == true
      CT.isEqual(charArr1, str1) == true
      CT.isEqual(charArr1, seq1) == true

      CT.isEqual(byteArr1, charArr2) == false
      CT.isEqual(byteArr1, byteArr2) == false
      CT.isEqual(byteArr1, str2) == false
      CT.isEqual(byteArr1, seq2) == false

      CT.isEqual(str1, charArr3) == false
      CT.isEqual(str1, byteArr3) == false
      CT.isEqual(str1, str3) == false
      CT.isEqual(str1, seq3) == false

      CT.isEqual(seq1, charArr4) == true
      CT.isEqual(seq1, byteArr4) == true
      CT.isEqual(seq1, str4) == true
      CT.isEqual(seq1, seq4) == true

      CT.isEqual(byteArr1, charArr5) == false
      CT.isEqual(str1, byteArr5) == false
      CT.isEqual(seq1, str5) == false
      CT.isEqual(charArr1, seq5) == false
