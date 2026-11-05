#!/usr/bin/env bash
# switches the native firebase config files to one environment
set -euo pipefail

if [[ $# -ne 1 || ($1 != production && $1 != staging) ]]; then
  echo "usage: $0 <production|staging>" >&2
  exit 1
fi
cd "$(dirname "$0")/.."

android_source="android/app/google-services.$1.json"
ios_source="ios/Runner/GoogleService-Info.$1.plist"

# both are checked first so a failure never leaves the platforms on different projects
for source in "$android_source" "$ios_source"; do
  if [[ ! -f $source ]]; then
    echo "missing $source, nothing was changed" >&2
    exit 1
  fi
done

cp "$android_source" android/app/google-services.json
cp "$ios_source" ios/Runner/GoogleService-Info.plist
echo "native firebase config switched to $1"
