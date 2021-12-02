proc add*(str: var string, chars: openArray[char]) =
  for c in chars:
    str.add c

