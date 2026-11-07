#!/usr/bin/env bash
# deploys functions, firestore rules and indexes to the staging alias only
# DRY_RUN=1 prints the deploy command without building or deploying
set -euo pipefail

production_id=numer-60744

fail() {
  echo "$1" >&2
  exit 1
}

[[ $# -eq 0 ]] || fail "this script takes no arguments"
[[ -f .firebaserc ]] || fail "no .firebaserc here, run from the repository root"

staging_id=$(sed -n 's/.*"staging"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .firebaserc)

[[ -n $staging_id ]] || fail "no staging alias in .firebaserc"
[[ $staging_id != "$production_id" ]] || fail "the staging alias points at production, refusing"
[[ -f functions/.env.$staging_id ]] || fail "missing functions/.env.$staging_id"

deploy=(firebase deploy --only "functions,firestore:rules,firestore:indexes" --project "$staging_id")

if [[ ${DRY_RUN:-} == 1 ]]; then
  echo "${deploy[*]}"
  exit 0
fi

(cd functions && npm run build)
"${deploy[@]}"
