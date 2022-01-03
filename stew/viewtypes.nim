when (NimMajor, NimMinor) < (1, 5):
  type Lent*[T] = T
else:
  type Lent*[T] = lent T
