#!/usr/bin/env bash
# measures the compressed size of the arm64 release apk, needs release signing and node
set -euo pipefail
cd "$(dirname "$0")/.."

log=$(mktemp)
trap 'rm -f "$log"' EXIT

flutter build apk --release --target-platform android-arm64 --analyze-size | tee "$log" >&2

summary=$(sed -n 's/^.*A summary of your APK analysis can be found at: //p' "$log")
if [[ ! -f $summary ]]; then
  echo "the size analysis summary is missing" >&2
  exit 1
fi
# the console total is rounded to whole megabytes and the root node of the summary stays 0
bytes=$(node -e '
  const { children } = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  console.log(children.reduce((total, child) => total + child.value, 0));
' "$summary")
echo "apkDownloadBytes=$bytes"
