import std/macros, ./assign2

macro evalOnceAs*(exp, alias: untyped): untyped =
  expectKind(alias, nnkIdent)
  let
    body = nnkStmtList.newTree()
    val = if exp.kind == nnkSym: exp
          else:
            let val = genSym(ident = "evalOnce_" & $alias)
            body.add newLetStmt(val, exp)
            val
  body.add(newProc(name = genSym(nskTemplate, $alias),
    params = [getType(untyped)], body = val, procType = nnkTemplateDef))
  body

type ArrayBuf*[N: static int, T] = object
  buf*: array[N, T]
  when sizeof(int) > sizeof(uint8):
    when N <= int(uint8.high):
      n*: uint8
    else:
      when sizeof(int) > sizeof(uint16):
        when N <= int(uint16.high):
          n*: uint16
        else:
          when sizeof(int) > sizeof(uint32):
            when N <= cast[int](uint32.high):
              n*: uint32
            else:
              n*: int
          else:
            n*: int
      else:
        n*: int
  else:
    n*: int
template len*(b: ArrayBuf): int =
  int(b.n)
template data*(bParam: ArrayBuf): openArray =
  bParam.evalOnceAs(bArrayBufPrivate)
  bArrayBufPrivate.buf.toOpenArray(0, bArrayBufPrivate.len() - 1)
template data*(bParam: var ArrayBuf): var openArray =
  bParam.evalOnceAs(bArrayBufPrivate)
  bArrayBufPrivate.buf.toOpenArray(0, bArrayBufPrivate.len() - 1)
