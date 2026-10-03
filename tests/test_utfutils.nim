# Copyright (c) 2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license: http://opensource.org/licenses/MIT
#   * Apache License, Version 2.0: http://www.apache.org/licenses/LICENSE-2.0
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [].}

import
  unittest2,
  ../stew/utfutils

const utf8Vectors = [
  ("", true, "empty"),
  ("hello, world", true, "ascii"),
  ("\x00\x01\x7F", true, "ascii controls"),

  ("\xC2\x80", true, "U+0080, shortest 2-byte"),
  ("\xDF\xBF", true, "U+07FF"),
  ("\xE0\xA0\x80", true, "U+0800, shortest 3-byte"),
  ("\xED\x9F\xBF", true, "U+D7FF, last before surrogates"),
  ("\xEE\x80\x80", true, "U+E000, first after surrogates"),
  ("\xEF\xBF\xBF", true, "U+FFFF"),
  ("\xF0\x90\x80\x80", true, "U+10000, shortest 4-byte"),
  ("\xF4\x8F\xBF\xBF", true, "U+10FFFF, last code point"),

  ("\x80", false, "lone continuation"),
  ("\xBF", false, "lone continuation"),
  ("\xC0\x80", false, "overlong NUL"),
  ("\xC1\xBF", false, "overlong U+007F"),
  ("\xE0\x9F\xBF", false, "overlong 3-byte"),
  ("\xF0\x8F\xBF\xBF", false, "overlong 4-byte"),
  ("\xED\xA0\x80", false, "surrogate U+D800"),
  ("\xED\xBF\xBF", false, "surrogate U+DFFF"),
  ("\xF4\x90\x80\x80", false, "U+110000, too large"),
  ("\xF5\x80\x80\x80", false, "F5 lead"),
  ("\xFF", false, "FF lead"),

  ("\xC2", false, "truncated 2-byte"),
  ("\xE0\xA0", false, "truncated 3-byte"),
  ("\xF0\x90\x80", false, "truncated 4-byte"),
  ("a\xF0\x90\x80", false, "truncated 4-byte after ascii"),
  ("\xC2\x41", false, "2-byte lead, non-continuation"),
  ("\xF0\xC2\x80", false, "4-byte lead, lead in place of continuation"),
  ("\xC2\x80\x80", false, "unrequired continuation"),
]

suite "Utf utils":
  test "Utf8 string validation":
    for (s, expected, name) in utf8Vectors:
      if validateUtf8(s) != expected:
        checkpoint("Failed (string): " & name)
        fail()

  test "Utf8 bytes validation":
    for (s, expected, name) in utf8Vectors:
      let b = block:
        var bb = newSeq[byte]()
        for c in s:
          bb.add byte(c)
        bb
      if validateUtf8(b) != expected:
        checkpoint("Failed (bytes): " & name)
        fail()

  test "Utf8 string stream validation":
    for (s, expected, name) in utf8Vectors:
      let got = block:
        var v: Utf8Validator
        for c in s:
          v.push(c)
        v.valid()
      if got != expected:
        checkpoint("Failed (string stream): " & name)
        fail()

  test "Utf8 bytes stream validation":
    for (s, expected, name) in utf8Vectors:
      let b = block:
        var bb = newSeq[byte]()
        for c in s:
          bb.add byte(c)
        bb
      let got = block:
        var v: Utf8Validator
        for c in b:
          v.push(c)
        v.valid()
      if got != expected:
        checkpoint("Failed (bytes stream): " & name)
        fail()

  test "utf8 clear validator":
    var v: Utf8Validator
    check v.valid()  # empty is valid
    v.push('\x80')
    check not v.valid()
    check not v.valid()  # still invalid
    v.clear()
    check v.valid()
    v.push('a')
    check v.valid()
