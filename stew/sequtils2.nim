import
  std/typetraits,
  ./assign2

func write*[T](s: var seq[T], v: openArray[T]) =
  # The Nim standard library is inefficient when copying simple types
  # into a seq: it will first zero-init the new memory then copy the items
  # one by one, when a copyMem would be sufficient - semantically, this
  # function performs the same thing as `add`, but similar to faststreams, from
  # where the `write` name comes from, it is much faster. Unfortunately, there's
  # no easy way to avoid the zero-init, but a smart compiler might be able
  # to elide it.
  when nimvm:
    s.add(v)
  else:
    if v.len > 0:
      let start = s.len
      s.setLen(start + v.len)
      when supportsCopyMem(T): # shortcut
        copyMem(addr s[start], unsafeAddr v[0], v.len * sizeof(T))
      else:
        assign(s.toOpenArray(start, s.high), v)
