import std/typetraits
export typetraits

when (NimMajor, NimMinor) < (1, 6):  # Copy from `std/typetraits`
  #
  #
  #            Nim's Runtime Library
  #        (c) Copyright 2012 Nim Contributors
  #
  #    See the file "copying.txt", included in this
  #    distribution, for details about the copyright.
  #

  type HoleyEnum* = (not Ordinal) and enum ## Enum with holes.
  type OrdinalEnum* = Ordinal and enum ## Enum without holes.
