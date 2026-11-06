#!/usr/bin/env bash
# source files stay under the limit; files listed in the baseline may only shrink
set -euo pipefail
cd "$(dirname "$0")/.."

limit=400
baseline=scripts/file_size_baseline.txt
fail=0

sizes=$(find lib packages/*/lib functions/src -type f \( -name '*.dart' -o -name '*.ts' \) \
  ! -path 'lib/l10n/*' ! -name '*.g.dart' -exec wc -l {} + | awk '$2 != "total" {print $1, $2}')

while read -r lines file; do
  allowed=$(awk -v f="$file" '$2 == f {print $1}' "$baseline")
  if [ -n "$allowed" ]; then
    if [ "$lines" -gt "$allowed" ]; then
      echo "$file grew to $lines lines (baseline $allowed); move code out instead"
      fail=1
    elif [ "$lines" -lt "$allowed" ]; then
      echo "$file shrank to $lines lines; lower its entry in $baseline"
      fail=1
    fi
  elif [ "$lines" -gt "$limit" ]; then
    echo "$file has $lines lines (limit $limit); split it by responsibility"
    fail=1
  fi
done <<< "$sizes"

while read -r _ file; do
  [ -f "$file" ] || { echo "$file is in $baseline but no longer exists; remove its entry"; fail=1; }
done < "$baseline"

exit "$fail"
