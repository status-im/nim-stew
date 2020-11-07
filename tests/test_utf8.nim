import std/unittest
import ../stew/utf8

proc toUTF4(value: uint32): array[4, byte] =
  doAssert(value >= 0x10000'u32 and value < 0x200000'u32)
  [
    0xF0'u8 or byte((value shr 18) and 0x07),
    0x80'u8 or byte((value shr 12) and 0x3F),
    0x80'u8 or byte((value shr 6) and 0x3F),
    0x80'u8 or byte(value and 0x3F)
  ]

proc toUTF3(value: uint32): array[3, byte] =
  doAssert(value >= 0x800'u32 and value < 0x10000'u32)
  [
    0xE0'u8 or byte((value shr 12) and 0x0F),
    0x80'u8 or byte((value shr 6) and 0x3F),
    0x80'u8 or byte(value and 0x3F)
  ]

proc toUTF2(value: uint32): array[2, byte] =
  doAssert(value >= 0x80'u32 and value < 0x800'u32)
  [
    0xC0'u8 or byte((value shr 6) and 0x1F),
    0x80'u8 or byte(value and 0x3F)
  ]

proc toUTF1(value: uint32): array[1, byte] =
  doAssert(value < 0x80'u32)
  [ byte(value and 0x7F) ]

suite "UTF-8 validation test suite":
  test "Values [U+0000, U+007F] are allowed":
    for i in 0x00'u32 .. 0x7F'u32:
      check utf8Validate(toUTF1(i)) == true
  test "Values [U+0080, U+07FF] are allowed":
    for i in 0x80'u32 .. 0x7FF'u32:
      check utf8Validate(toUTF2(i)) == true
  test "Values [U+0800, U+D7FF] are allowed":
    for i in 0x800'u32 .. 0xD7FF'u32:
      check utf8Validate(toUTF3(i)) == true
  test "Values [U+D800, U+DFFF] (UTF-16 surrogates) are not allowed":
    for i in 0xD800'u32 .. 0xDFFF'u32:
      check utf8Validate(toUTF3(i)) == false
  test "Values [U+E000, U+FFFD] are allowed":
    for i in 0xE000'u32 .. 0xFFFD'u32:
      check utf8Validate(toUTF3(i)) == true
  test "Values U+FFFE and U+FFFF are not allowed":
    check:
      utf8Validate(toUTF3(0xFFFE'u32)) == false
      utf8Validate(toUTF3(0xFFFF'u32)) == false
  test "Values [U+10000, U10FFFF] are allowed":
    for i in 0x10000'u32 .. 0x10FFFF'u32:
      check utf8Validate(toUTF4(i)) == true
  test "Values bigger U+10FFFF are not allowed":
    for i in 0x11_0000'u32 .. 0x1F_FFFF'u32:
      check utf8Validate(toUTF4(i)) == false
  test "fastvalidate-utf-8 bad sequences":
    # https://github.com/lemire/fastvalidate-utf-8 test vectors
    const
      GoodSequences = [
        "a",
        "\xc3\xb1",
        "\xe2\x82\xa1",
        "\xf0\x90\x8c\xbc",
        "안녕하세요, 세상",
        "\xc2\x80",
        "\xf0\x90\x80\x80",
        "\xee\x80\x80"
      ]

      BadSequences = [
        "\xc3\x28",
        "\xa0\xa1",
        "\xe2\x28\xa1",
        "\xe2\x82\x28",
        "\xf0\x28\x8c\xbc",
        "\xf0\x90\x28\xbc",
        "\xf0\x28\x8c\x28",
        "\xc0\x9f",
        "\xf5\xff\xff\xff",
        "\xed\xa0\x81",
        "\xf8\x90\x80\x80\x80",
        "123456789012345\xed",
        "123456789012345\xf1",
        "123456789012345\xc2",
        "\xC2\x7F",
        "\xce",
        "\xce\xba\xe1",
        "\xce\xba\xe1\xbd",
        "\xce\xba\xe1\xbd\xb9\xcf",
        "\xce\xba\xe1\xbd\xb9\xcf\x83\xce",
        "\xce\xba\xe1\xbd\xb9\xcf\x83\xce\xbc\xce",
        "\xdf",
        "\xef\xbf"
      ]
    for item in BadSequences:
      check utf8Validate(item) == false
    for item in GoodSequences:
      check utf8Validate(item) == true
  test "UTF-8 decoder capability and stress test":
    # https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
    const Tests2 = [
      # Boundary condition test cases
      ("\x00", true),
      ("\xc2\x80", true),
      ("\xe0\xa0\x80", true),
      ("\xf0\x90\x80\x80", true),
      ("\xf8\x88\x80\x80\x80", false),
      ("\xfc\x84\x80\x80\x80\x80", false),
      ("\x7f", true),
      ("\xdf\xbf", true),
      ("\xef\xbf\xbf", false),
      ("\xf7\xbf\xbf\xbf", false),
      ("\xfb\xbf\xbf\xbf\xbf", false),
      ("\xfd\xbf\xbf\xbf\xbf\xbf", false),
      ("\xed\x9f\xbf", true),
      ("\xee\x80\x80", true),
      ("\xef\xbf\xbd", true),
      ("\xf4\x8f\xbf\xbf", true),
    ]

    const Tests3 = [
      # Malformed sequences
      ("\x80", false),
      ("\xbf", false),
      ("\x80\xbf", false),
      ("\x80\xbf\x80", false),
      ("\x80\xbf\x80\xbf", false),
      ("\x80\xbf\x80\xbf\x80", false),
      ("\x80\xbf\x80\xbf\x80\xbf", false),
      ("\x80\xbf\x80\xbf\x80\xbf\x80", false),
      ("\xc0", false),
      ("\xe0\x80", false),
      ("\xf0\x80\x80", false),
      ("\xf8\x80\x80\x80", false),
      ("\xfc\x80\x80\x80\x80", false),
      ("\xdf", false),
      ("\xef\xbf", false),
      ("\xf7\xbf\xbf", false),
      ("\xfb\xbf\xbf\xbf", false),
      ("\xfd\xbf\xbf\xbf\xbf", false),
      ("\xfe", false),
      ("\xff", false),
      ("\xfe\xfe\xff\xff", false)
    ]

    const Tests4 = [
      # Overlong sequences
      ("\xc0\xaf", false),
      ("\xe0\x80\xaf", false),
      ("\xf0\x80\x80\xaf", false),
      ("\xf8\x80\x80\x80\xaf", false),
      ("\xfc\x80\x80\x80\x80\xaf", false),
      ("\xc1\xbf", false),
      ("\xe0\x9f\xbf", false),
      ("\xf0\x8f\xbf\xbf", false),
      ("\xf8\x87\xbf\xbf\xbf", false),
      ("\xfc\x83\xbf\xbf\xbf\xbf", false),
      ("\xc0\x80", false),
      ("\xe0\x80\x80", false),
      ("\xf0\x80\x80\x80", false),
      ("\xf8\x80\x80\x80\x80", false),
      ("\xfc\x80\x80\x80\x80\x80", false)
    ]

    const Tests5 = [
      # Illegal code positions
      ("\xed\xa0\x80", false),
      ("\xed\xad\xbf", false),
      ("\xed\xae\x80", false),
      ("\xed\xaf\xbf", false),
      ("\xed\xb0\x80", false),
      ("\xed\xbe\x80", false),
      ("\xed\xbf\xbf", false),
      ("\xed\xa0\x80\xed\xb0\x80", false),
      ("\xed\xa0\x80\xed\xbf\xbf", false),
      ("\xed\xad\xbf\xed\xb0\x80", false),
      ("\xed\xad\xbf\xed\xbf\xbf", false),
      ("\xed\xae\x80\xed\xb0\x80", false),
      ("\xed\xae\x80\xed\xbf\xbf", false),
      ("\xed\xaf\xbf\xed\xb0\x80", false),
      ("\xed\xaf\xbf\xed\xbf\xbf", false)
    ]

    for item in Tests2:
      check utf8Validate(item[0]) == item[1]
    for item in Tests3:
      check utf8Validate(item[0]) == item[1]
    for item in Tests4:
      check utf8Validate(item[0]) == item[1]
    for item in Tests5:
      check utf8Validate(item[0]) == item[1]

  test "UTF-8 length() test":
    const
      Cyrillic = "\xd0\x9f\xd1\x80\xd0\xbe\xd0\xb3" &
                 "\xd1\x80\xd0\xb0\xd0\xbc\xd0\xbc\xd0\xb0"
    check:
      utf8Length("Программа").tryGet() == 9
      utf8Length("Программ").tryGet() == 8
      utf8Length("Програм").tryGet() == 7
      utf8Length("Програ").tryGet() == 6
      utf8Length("Прогр").tryGet() == 5
      utf8Length("Прог").tryGet() == 4
      utf8Length("Про").tryGet() == 3
      utf8Length("Пр").tryGet() == 2
      utf8Length("П").tryGet() == 1
      utf8Length("").tryGet() == 0
      utf8Length("П⠯🤗").tryGet() == 3
      utf8Length("⠯🤗").tryGet() == 2
      utf8Length("🤗").tryGet() == 1

    check:
      utf8Length(Cyrillic).tryGet() == 9
      utf8Length(Cyrillic.toOpenArray(0, len(Cyrillic) - 2)).isErr() == true

  test "UTF-8 substr() test":
    check:
      utf8Substr("Программа", -1, -1).tryGet() == "Программа"
      utf8Substr("Программа", 0, 0).tryGet() == "П"
      utf8Substr("Программа", 0, 1).tryGet() == "Пр"
      utf8Substr("Программа", 0, 2).tryGet() == "Про"
      utf8Substr("Программа", 0, 3).tryGet() == "Прог"
      utf8Substr("Программа", 0, 4).tryGet() == "Прогр"
      utf8Substr("Программа", 0, 5).tryGet() == "Програ"
      utf8Substr("Программа", 0, 6).tryGet() == "Програм"
      utf8Substr("Программа", 0, 7).tryGet() == "Программ"
      utf8Substr("Программа", 0, 8).tryGet() == "Программа"
      utf8Substr("Программа", 0, 9).tryGet() == "Программа"
      utf8Substr("Программа", 0, 10).tryGet() == "Программа"
      utf8Substr("Программа", 0, 18).tryGet() == "Программа"
      utf8Substr("Программа", 0, 19).tryGet() == "Программа"
      utf8Substr("Программа", 0, 100).tryGet() == "Программа"
      utf8Substr("Программа", 100, 0).tryGet() == ""
      utf8Substr("Программа", 100, 100).tryGet() == ""
      utf8Substr("Программа", 1, 1).tryGet() == "р"
      utf8Substr("Программа", 2, 2).tryGet() == "о"
      utf8Substr("Программа", 3, 3).tryGet() == "г"
      utf8Substr("Программа", 4, 4).tryGet() == "р"
      utf8Substr("Программа", 5, 5).tryGet() == "а"
      utf8Substr("Программа", 6, 6).tryGet() == "м"
      utf8Substr("Программа", 7, 7).tryGet() == "м"
      utf8Substr("Программа", 8, 8).tryGet() == "а"
      utf8Substr("Программа", 9, 9).tryGet() == ""
      utf8Substr("Программа", 0, -1).tryGet() == "Программа"
      utf8Substr("Программа", 1, -1).tryGet() == "рограмма"
      utf8Substr("Программа", 2, -1).tryGet() == "ограмма"
      utf8Substr("Программа", 3, -1).tryGet() == "грамма"
      utf8Substr("Программа", 4, -1).tryGet() == "рамма"
      utf8Substr("Программа", 5, -1).tryGet() == "амма"
      utf8Substr("Программа", 6, -1).tryGet() == "мма"
      utf8Substr("Программа", 7, -1).tryGet() == "ма"
      utf8Substr("Программа", 8, -1).tryGet() == "а"
      utf8Substr("Программа", 9, -1).tryGet() == ""

      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", -1, -1).tryGet() == "⠯⠰⠱⠲⠳⠴⠵⠶"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 0).tryGet() == "⠯"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 1).tryGet() == "⠯⠰"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 2).tryGet() == "⠯⠰⠱"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 3).tryGet() == "⠯⠰⠱⠲"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 4).tryGet() == "⠯⠰⠱⠲⠳"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 5).tryGet() == "⠯⠰⠱⠲⠳⠴"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 6).tryGet() == "⠯⠰⠱⠲⠳⠴⠵"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 7).tryGet() == "⠯⠰⠱⠲⠳⠴⠵⠶"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 8).tryGet() == "⠯⠰⠱⠲⠳⠴⠵⠶"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 9).tryGet() == "⠯⠰⠱⠲⠳⠴⠵⠶"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 23).tryGet() == "⠯⠰⠱⠲⠳⠴⠵⠶"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 24).tryGet() == "⠯⠰⠱⠲⠳⠴⠵⠶"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 0, 100).tryGet() == "⠯⠰⠱⠲⠳⠴⠵⠶"
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 100, 0).tryGet() == ""
      utf8Substr("⠯⠰⠱⠲⠳⠴⠵⠶", 100, 100).tryGet() == ""

      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", -1, -1).tryGet() ==
        "🤗🤘🤙🤚🤛🤜🤝🤞🤟"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 0).tryGet() ==
        "🤗"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 1).tryGet() ==
        "🤗🤘"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 2).tryGet() ==
        "🤗🤘🤙"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 3).tryGet() ==
        "🤗🤘🤙🤚"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 4).tryGet() ==
        "🤗🤘🤙🤚🤛"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 5).tryGet() ==
        "🤗🤘🤙🤚🤛🤜"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 6).tryGet() ==
        "🤗🤘🤙🤚🤛🤜🤝"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 7).tryGet() ==
        "🤗🤘🤙🤚🤛🤜🤝🤞"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 8).tryGet() ==
        "🤗🤘🤙🤚🤛🤜🤝🤞🤟"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 9).tryGet() ==
        "🤗🤘🤙🤚🤛🤜🤝🤞🤟"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 31).tryGet() ==
        "🤗🤘🤙🤚🤛🤜🤝🤞🤟"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 32).tryGet() ==
        "🤗🤘🤙🤚🤛🤜🤝🤞🤟"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 0, 100).tryGet() ==
        "🤗🤘🤙🤚🤛🤜🤝🤞🤟"
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 100, 0).tryGet() == ""
      utf8Substr("🤗🤘🤙🤚🤛🤜🤝🤞🤟", 100, 100).tryGet() == ""

  test "UTF-32 -> UTF-8 conversion test":
    for i in 0 ..< 0x11_0000:
      var data32 = [uint32(i)]
      if i >= 0xD800 and i <= 0xDFFF:
        check utf32toUtf8(data32).isErr()
      elif i == 0xFFFE:
        check utf32toUtf8(data32).isErr()
      elif i == 0xFFFF:
        check utf32toUtf8(data32).isErr()
      elif i == 0x11_0000:
        check utf32toUtf8(data32).isErr()
      else:
        var data32 = [uint32(i)]
        let res = utf32toUtf8(data32)
        check:
          res.isOk() == true
          utf8Validate(res.get()) == true

  test "UTF-8 -> UTF-32 conversion test":
    for i in 0 ..< 0x11_0001:
      var data32 = [uint32(i)]
      if i >= 0xD800 and i <= 0xDFFF:
        check utf32toUtf8(data32).isErr()
      elif i == 0xFFFE:
        check utf32toUtf8(data32).isErr()
      elif i == 0xFFFF:
        check utf32toUtf8(data32).isErr()
      elif i == 0x11_0000:
        check utf32toUtf8(data32).isErr()
      else:
        var data32 = [uint32(i)]
        let res8 = utf32toUtf8(data32)
        check res8.isOk()
        let res32 = utf8toUtf32(uint32, res8.get())
        check:
          res32.isOk()
          res32.get() == data32
