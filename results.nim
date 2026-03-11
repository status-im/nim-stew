type
  Result*[T, E] = object
    when T is void:
      when E is void:
        oResultPrivate*: bool
      else:
        case oResultPrivate*: bool
        of false:
          eResultPrivate*: E
        of true:
          discard
    else:
      when E is void:
        case oResultPrivate*: bool
        of false:
          discard
        of true:
          vResultPrivate*: T
      else:
        case oResultPrivate*: bool
        of false:
          eResultPrivate*: E
        of true:
          vResultPrivate*: T
  Opt*[T] = Result[T, void]

template ok*[T: not void, E](R: type Result[T, E], x: untyped): R =
  R(oResultPrivate: true, vResultPrivate: x)
template err*[T; E: not void](R: type Result[T, E], x: untyped): R =
  R(oResultPrivate: false, eResultPrivate: x)
template err*[T](R: type Result[T, void]): R =
  R(oResultPrivate: false)
template ok*(v: auto): auto =
  ok(typeof(result), v)
template err*(v: auto): auto =
  err(typeof(result), v)

template some*[T](O: type Opt, v: T): Opt[T] =
  ok(Opt[T], v)
template none*(O: type Opt, T: type): Opt[T] =
  err(Opt[T])

template valueOr*[T: not void, E](self: Result[T, E], def: untyped): T =
  let s = (self)
  case s.oResultPrivate
  of true:
    s.vResultPrivate
  of false:
    when E isnot void:
      template error(): E {.used.} =
        s.eResultPrivate
    def

template `?`*[T, E](self: Result[T, E]): auto =
  let v = (self)
  case v.oResultPrivate
  of false:
    when typeof(result) is typeof(v):
      result = v
      return
    else:
      when E is void:
        result = err(typeof(result))
        return
      else:
        result = err(typeof(result), v.eResultPrivate)
        return
  of true:
    when not (T is void):
      v.vResultPrivate
