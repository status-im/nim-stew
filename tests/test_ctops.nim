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

      int8Arr = [1'i8, 2'i8, 3'i8]
      int16Arr = [1'i16, 2'i16, 3'i16]
      int32Arr = [1'i32, 2'i32, 3'i32]
      intArr = [1, 2, 3]

      uint8Arr = [1'u8, 2'u8, 3'u8]
      uint16Arr = [1'u16, 2'u16, 3'u16]
      uint32Arr = [1'u32, 2'u32, 3'u32]
      uintArr = [1'u, 2'u, 3'u]

    var
      emptyArray: array[0, byte]
      emptyString = ""
      emptySeq = newSeq[byte]()

    when sizeof(int) == 8:
      let
        int64Arr = [1'i64, 2'i64, 3'i64]
        uint64Arr = [1'u64, 2'u64, 3'u64]

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

      CT.isEqual(int8Arr, int8Arr) == true
      CT.isEqual(int8Arr, uint8Arr) == true
      CT.isEqual(int16Arr, int16Arr) == true
      CT.isEqual(int16Arr, uint16Arr) == true
      CT.isEqual(int32Arr, int32Arr) == true
      CT.isEqual(int32Arr, uint32Arr) == true
      CT.isEqual(intArr, intArr) == true
      CT.isEqual(intArr, uintArr) == true

    when sizeof(int) == 8:
      check:
        CT.isEqual(int64Arr, int64Arr) == true
        CT.isEqual(int64Arr, uint64Arr) == true

    # Empty arrays
    expect(AssertionError):
      discard CT.isEqual(emptyArray, emptyArray)
    expect(AssertionError):
      discard CT.isEqual(emptyArray, emptyString)
    expect(AssertionError):
      discard CT.isEqual(emptyArray, emptySeq)

    # Arrays, where T is different type size
    expect(AssertionError):
      discard CT.isEqual(int8Arr, int16Arr)
    expect(AssertionError):
      discard CT.isEqual(int16Arr, int32Arr)
    expect(AssertionError):
      discard CT.isEqual(int8Arr, intArr)
