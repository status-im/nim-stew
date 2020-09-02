proc add*(str: var string, chars: openarray[char]) =
  for c in chars:
    str.add c

