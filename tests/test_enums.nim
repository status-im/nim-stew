import
  unittest, typetraits,
  ../stew/enums

suite "enums":
  test "enumRangeInt64":
    type
      WithoutHoles = enum
        A1, A2, A3
      WithoutHoles2 = enum
        B1 = 4, B2 = 5, B3 = 6
      WithHoles = enum
        C1 = 1, C2 = 3, C3 = 5

    check:
      enumRangeInt64(WithoutHoles) == [ 0'i64, 1, 2 ]
      enumRangeInt64(WithoutHoles2) == [ 4'i64, 5, 6 ]
      enumRangeInt64(WithHoles) == [ 1'i64, 3, 5 ]

  test "enumStringValues":
    type
      RegularEnum = enum
        A1, A2, A3

      EnumWithHoles = enum
        C1 = 1, C2 = 3, C3 = 5

      StringyEnum = enum
        A = "value A"
        B = "value B"

    check:
      enumStrValuesArray(RegularEnum) == ["A1", "A2", "A3"]
      enumStrValuesArray(EnumWithHoles) == ["C1", "C2", "C3"]
      enumStrValuesArray(StringyEnum) == ["value A", "value B"]

      enumStrValuesSeq(RegularEnum) == @["A1", "A2", "A3"]
      enumStrValuesSeq(EnumWithHoles) == @["C1", "C2", "C3"]
      enumStrValuesSeq(StringyEnum) == @["value A", "value B"]

  test "contains":
    type
      WithoutHoles = enum
        A1, A2, A3
      WithoutHoles2 = enum
        B1 = 4, B2 = 5, B3 = 6
      WithHoles = enum
        C1 = 1, C2 = 3, C3 = 5
      WithoutHoles3 = enum
        D1 = -1, D2 = 0, D3 = 1
      WithHoles2 = enum
        E1 = -5, E2 = 0, E3 = 5

    check:
      1 in WithoutHoles
      5 notin WithoutHoles
      1 notin WithoutHoles2
      5 in WithoutHoles2
      1 in WithHoles
      2 notin WithHoles
      6 notin WithHoles
      5 in WithHoles
      1.byte in WithoutHoles
      4294967295'u32 notin WithoutHoles3
      -1.int8 in WithoutHoles3
      -4.int16 notin WithoutHoles3
      -5.int16 in WithHoles2
      5.uint64 in WithHoles2
      -12.int8 notin WithHoles2
      int64.high notin WithoutHoles
      int64.high notin WithHoles
      int64.low notin WithoutHoles
      int64.low notin WithHoles
      int64.high.uint64 * 2 notin WithoutHoles
      int64.high.uint64 * 2 notin WithHoles

  test "hasHoles":
    type
      EnumWithOneValue = enum
        A0

      WithoutHoles = enum
        A1, B1, C1

      WithoutHoles2 = enum
        A2 = 2, B2 = 3, C2 = 4

      WithHoles = enum
        A3, B3 = 2, C3

      WithBigHoles = enum
        A4 = 0, B4 = 2000, C4 = 4000

    check:
      hasHoles(EnumWithOneValue) == false
      hasHoles(WithoutHoles) == false
      hasHoles(WithoutHoles2) == false
      hasHoles(WithHoles) == true
      hasHoles(WithBigHoles) == true

  test "checkedEnumAssign":
    type
      SomeEnum = enum
        A1, B1, C1

      AnotherEnum = enum
        A2 = 2, B2, C2

      EnumWithHoles = enum
        A3, B3 = 3, C3
    var
      e1 = A1
      e2 = A2
      e3 = A3

    check:
      checkedEnumAssign(e1, 2)
      e1 == C1
      not checkedEnumAssign(e1, 5)
      e1 == C1
      checkedEnumAssign(e1, 0)
      e1 == A1
      not checkedEnumAssign(e1, -1)
      e1 == A1

      checkedEnumAssign(e2, 2)
      e2 == A2
      not checkedEnumAssign(e2, 5)
      e2 == A2
      checkedEnumAssign(e2, 4)
      e2 == C2
      not checkedEnumAssign(e2, 1)
      e2 == C2

      checkedEnumAssign(e3, 4)
      e3 == C3
      not checkedEnumAssign(e3, 1)
      e3 == C3
      checkedEnumAssign(e3, 0)
      e3 == A3
      not checkedEnumAssign(e3, -1)
      e3 == A3

