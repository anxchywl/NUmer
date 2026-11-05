#!/usr/bin/env bash
# measures cold start in profile mode, usage: measure_startup.sh [device id]
set -euo pipefail
cd "$(dirname "$0")/.."

trace=build/start_up_info.json
# a trace left by an earlier run must not pass for this one
rm -f "$trace"

flutter run --profile --trace-startup ${1:+-d "$1"} >&2

if [[ ! -f $trace ]]; then
  echo "$trace is missing" >&2
  exit 1
fi
micros=$(sed -n 's/.*"timeToFirstFrameMicros": *\([0-9][0-9]*\).*/\1/p' "$trace")
if [[ -z $micros ]]; then
  echo "timeToFirstFrameMicros is missing from $trace" >&2
  exit 1
fi
echo "timeToFirstFrameMs=$((micros / 1000))"
