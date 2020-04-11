mode = ScriptMode.Verbose

packageName   = "stew"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Backports, standard library candidates and small utilities that don't yet deserve their own repository"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 1.2.0"

task test, "Run all tests":
  exec "nim c -r --threads:off tests/all_tests"
  exec "nim c -r --threads:on -d:nimTypeNames tests/all_tests"
