#!/usr/bin/env bash
# starts the auth, functions and firestore emulators under the staging project id
# DRY_RUN=1 prints the emulator command without building or starting
set -euo pipefail

production_id=numer-60744
secrets=functions/.secret.local

fail() {
  echo "$1" >&2
  exit 1
}

[[ $# -eq 0 ]] || fail "this script takes no arguments"
cd "$(dirname "$0")/.."

staging_id=$(sed -n 's/.*"staging"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .firebaserc)

[[ -n $staging_id ]] || fail "no staging alias in .firebaserc"
[[ $staging_id != "$production_id" ]] || fail "the staging alias points at production, refusing"

# a secret missing here is read from the project's secret manager by the emulator
[[ -f $secrets ]] || fail "missing $secrets, copy $secrets.example"
while IFS='=' read -r name _; do
  grep -q "^$name=." "$secrets" || fail "$name is not set in $secrets"
done < <(grep '^[A-Z]' "$secrets.example")

emulators=(firebase emulators:start --only "auth,functions,firestore" --project "$staging_id")

if [[ ${DRY_RUN:-} == 1 ]]; then
  echo "${emulators[*]}"
  exit 0
fi

(cd functions && npm run build)
"${emulators[@]}"
