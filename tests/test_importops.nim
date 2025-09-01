import ../stew/importops

when tryImport std / tables:
  discard Table[string, string]() # avoid unused warning
else:
  {.error: "tables should exist".}

when tryImport std / sets as s:
  discard s.HashSet[string]()
else:
  {.error: "tables should exist".}

when tryImport shouldnt_exist_at_all:
  {.error: "really?".}
