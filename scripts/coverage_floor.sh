#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <lcov file> <floor percent>" >&2
  exit 2
fi

awk -F: -v floor="$2" '
  /^SF:/ { skip = index($2, "lib/l10n/") == 1 }
  /^LF:/ && !skip { found += $2 }
  /^LH:/ && !skip { hit += $2 }
  END {
    if (found == 0) {
      print "no coverage records" > "/dev/stderr"
      exit 1
    }
    percent = hit * 100 / found
    printf "line coverage %.1f%% (floor %s%%)\n", percent, floor
    exit percent < floor + 0
  }
' "$1"
