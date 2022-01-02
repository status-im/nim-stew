mode = ScriptMode.Verbose

packageName   = "stew"
version       = "0.1.0"
author        = "Status Research & Development GmbH"
description   = "Backports, standard library candidates and small utilities that don't yet deserve their own repository"
license       = "Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 1.2.0"

### Helper functions
proc test(args, path: string) =
  # Compilation language is controlled by TEST_LANG
  exec "nim " & getEnv("TEST_LANG", "c") & " " & getEnv("NIMFLAGS") & " " & args &
    " -r --hints:off --skipParentCfg --styleCheck:usages --styleCheck:error " & path

task test, "Run all tests":
  test "--threads:off", "tests/all_tests"
  test "--threads:on -d:nimTypeNames", "tests/all_tests"
  test "--threads:on -d:noIntrinsicsBitOpts -d:noIntrinsicsEndians", "tests/all_tests"

task testvcc, "Run all tests with vcc compiler":
  test "--cc:vcc --threads:off", "tests/all_tests"
  test "--cc:vcc --threads:on -d:nimTypeNames", "tests/all_tests"
  test "--cc:vcc --threads:on -d:noIntrinsicsBitOpts -d:noIntrinsicsEndians", "tests/all_tests"
