mode = ScriptMode.Verbose

packageName   = "stew"
version       = "0.4.1"
author        = "Status Research & Development GmbH"
description   = "Backports, standard library candidates and small utilities that don't yet deserve their own repository"
license       = "MIT or Apache License 2.0"
skipDirs      = @["tests"]

requires "nim >= 1.6.0",
         "results",
         "unittest2"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0") &
  " --skipParentCfg --skipUserCfg --outdir:build --nimcache:build/nimcache -f"

proc build(args, path: string) =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path

proc run(args, path: string) =
  build args & " -r", path

task test, "Run all tests":
  build "", "tests/test_helper"
  for args in [
      "--threads:off",
      "--threads:on -d:nimTypeNames",
      "--threads:on -d:noIntrinsicsBitOpts -d:noIntrinsicsEndians"]:
    run args & " --mm:refc", "tests/all_tests"
    if (NimMajor, NimMinor) > (1, 6):
      run args & " --mm:orc", "tests/all_tests"
