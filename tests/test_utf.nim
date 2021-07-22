## utf
## Copyright (c) 2021 Status Research & Development GmbH
## Licensed under either of
##  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
##  * MIT license ([LICENSE-MIT](LICENSE-MIT))
## at your option.
## This file may not be copied, modified, or distributed except according to
## those terms.

import
  std/[unittest],
  ../stew/utf

suite "UTF-8 DFA validator":
  test "single octet":
    check:
      Utf8.validate("\x01")
      Utf8.validate("\x32")
      Utf8.validate("\x7f")
      Utf8.validate("\x80") == false

  test "two octets":
    check:
      Utf8.validate("\xc2\x80")
      Utf8.validate("\xc4\x80")
      Utf8.validate("\xdf\xbf")
      Utf8.validate("\xdfu\xc0") == false
      Utf8.validate("\xdf") == false

  test "three octets":
    check:
      Utf8.validate("\xe0\xa0\x80")
      Utf8.validate("\xe1\x80\x80")
      Utf8.validate("\xef\xbf\xbf")
      Utf8.validate("\xef\xbf\xc0") == false
      Utf8.validate("\xef\xbf") == false

  test "four octets":
    check:
      Utf8.validate("\xf0\x90\x80\x80")
      Utf8.validate("\xf0\x92\x80\x80")
      Utf8.validate("\xf0\x9f\xbf\xbf")
      Utf8.validate("\xf0\x9f\xbf\xc0") == false
      Utf8.validate("\xf0\x9f\xbf") == false

  test "overlong sequence":
    check:
      Utf8.validate("\xc0\xaf") == false
      Utf8.validate("\xe0\x80\xaf") == false
      Utf8.validate("\xf0\x80\x80\xaf") == false
      Utf8.validate("\xf8\x80\x80\x80\xaf") == false
      Utf8.validate("\xfc\x80\x80\x80\x80\xaf") == false

  test "max overlong sequence":
    check:
      Utf8.validate("\xc1\xbf") == false
      Utf8.validate("\xe0\x9f\xbf") == false
      Utf8.validate("\xf0\x8f\xbf\xbf") == false
      Utf8.validate("\xf8\x87\xbf\xbf\xbf") == false
      Utf8.validate("\xfc\x83\xbf\xbf\xbf\xbf") == false

  test "distinct codepoint":
    check:
      Utf8.validate("foobar")
      Utf8.validate("foob\xc3\xa6r")
      Utf8.validate("foob\xf0\x9f\x99\x88r")

  test "boundary test":
    check:
      Utf8.validate("κόσμε")
      Utf8.validate("\xC2\x80")
      Utf8.validate("\xE0\xA0\x80")
      Utf8.validate("\xF0\x90\x80\x80")
      Utf8.validate("\xF8\x88\x80\x80\x80") == false
      Utf8.validate("\xFC\x84\x80\x80\x80\x80") == false
      Utf8.validate("\x7F")
      Utf8.validate("\xDF\xBF")
      Utf8.validate("\xEF\xBF\xBF")
      Utf8.validate("\xF4\x8F\xBF\xBF")
      Utf8.validate("\xF4\x90\x80\x80") == false
      Utf8.validate("\xFB\xBF\xBF\xBF\xBF") == false
      Utf8.validate("\xFD\xBF\xBF\xBF\xBF\xBF") == false
      Utf8.validate("\xed\x9f\xbf")
      Utf8.validate("\xee\x80\x80")
      Utf8.validate("\xef\xbf\xbd")

#[
import unicode, strutils
func toHex(s: string): string =
  for c in s:
    result.add toHex(c.int, 2)


echo toUTF8(0x110000.Rune).toHex

]#