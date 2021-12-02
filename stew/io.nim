when not compiles(writeFile("filename", @[byte(1)])):
  proc writeFile*(filename: string, content: openArray[byte]) =
    ## Opens a file named `filename` for writing. Then writes the
    ## `content` completely to the file and closes the file afterwards.
    ## Raises an IO exception in case of an error.
    var f: File
    if open(f, filename, fmWrite):
      try:
        f.writeBuffer(unsafeAddr content[0], content.len)
      finally:
        close(f)
    else:
      raise newException(IOError, "cannot open: " & filename)

