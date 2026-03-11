#!/usr/bin/env bash
# Test harness: compile eth/common/keys.nim once per config, then run the
# resulting binary repeatedly to check for SIGSEGV.
#
# Uses setarch -R to disable ASLR for deterministic results.
#
# Matrix:
#   ORC + -d:release    → 200 trials (the bug we're hunting)
#   ORC + debug         →  10 trials (expected to pass)
#   refc + -d:release   →  10 trials (expected to pass)
#   refc + debug        →  10 trials (expected to pass)

ORC_RELEASE_TRIALS=400
OTHER_TRIALS=10
SOURCE="keys.nim"
COMPILERS=("$HOME/nim231/bin/nim" "$HOME/nim229/bin/nim" "$HOME/nim228/bin/nim")
NOASLR="setarch $(uname -m) -R"

# ORC is default for these Nim versions; refc needs --mm:refc
CONFIGS=(
  "orc|release|-d:release|$ORC_RELEASE_TRIALS"
  "orc|release+O2|-d:release --opt:none --passC:-O2 --passL:-O2|$ORC_RELEASE_TRIALS"
  "orc|debug||$OTHER_TRIALS"
  "refc|release|--mm:refc -d:release|$OTHER_TRIALS"
  "orc|release+clang|--cc:clang -d:release|$OTHER_TRIALS"
  "orc|release+malloc|-d:release -d:useMalloc|$ORC_RELEASE_TRIALS"
)

cd "$(dirname "$0")"

echo "================================================================"
echo "ORC+release trials: $ORC_RELEASE_TRIALS   other: $OTHER_TRIALS"
echo "ASLR: disabled via setarch -R"
echo "================================================================"
echo ""

for compiler in "${COMPILERS[@]}"; do
  version=$("$compiler" --version 2>&1 | head -1 | sed 's/Nim Compiler Version //' | sed 's/ \[.*//')

  for cfg in "${CONFIGS[@]}"; do
    IFS='|' read -r mm mode flags trials <<< "$cfg"
    label="$mm+$mode"

    outf=$(mktemp)

    echo "Compiling: Nim $version  $label ..."
    rm -rf ~/.cache/nim/
    # shellcheck disable=SC2086
    if ! "$compiler" c -f $flags --verbosity:0 -o:"$outf" "$SOURCE" >/dev/null 2>&1; then
      echo "  COMPILE FAILED"
      rm -f "$outf"
      continue
    fi

    segfaults=0
    successes=0
    other=0

    for ((i = 1; i <= trials; i++)); do
      $NOASLR "$outf" >/dev/null 2>&1
      rc=$?
      if [[ $rc -eq 0 ]]; then
        ((successes++))
      elif [[ $rc -eq 139 ]] || [[ $rc -eq 134 ]]; then
        ((segfaults++))
      else
        ((other++))
      fi
    done

    rm -f "$outf"

    printf "Nim %-7s  %-14s  CRASH: %3d/%-3d  OK: %3d/%-3d  other: %d/%d\n" \
      "$version" "$label" \
      "$segfaults" "$trials" \
      "$successes" "$trials" \
      "$other" "$trials"
  done
  echo ""
done
