#!/usr/bin/env bash
# switches the native firebase config files to one environment
# a production file with no saved copy is saved before anything replaces it
set -euo pipefail

production_id=numer-60744

if [[ $# -ne 1 || ($1 != production && $1 != staging) ]]; then
  echo "usage: $0 <production|staging>" >&2
  exit 1
fi
cd "$(dirname "$0")/.."

android_active=android/app/google-services.json
android_prefix=android/app/google-services
ios_active=ios/Runner/GoogleService-Info.plist
ios_prefix=ios/Runner/GoogleService-Info

keep_production() {
  local active=$1 saved=$2
  [[ -f $active ]] || return 0
  grep -q "$production_id" "$active" || return 0
  if [[ ! -f $saved ]]; then
    cp "$active" "$saved"
    echo "saved the current production config to $saved"
    return 0
  fi
  cmp -s "$active" "$saved" && return 0
  echo "$active and $saved are different production files, keep one in $saved and retry" >&2
  exit 1
}

keep_production "$android_active" "$android_prefix.production.json"
keep_production "$ios_active" "$ios_prefix.production.plist"

android_source="$android_prefix.$1.json"
ios_source="$ios_prefix.$1.plist"

# both are checked first so a failure never leaves the platforms on different projects
for source in "$android_source" "$ios_source"; do
  if [[ ! -f $source ]]; then
    echo "missing $source, the native config was not switched" >&2
    exit 1
  fi
done

cp "$android_source" "$android_active"
cp "$ios_source" "$ios_active"
echo "native firebase config switched to $1"
