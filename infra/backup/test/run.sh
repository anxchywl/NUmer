#!/usr/bin/env bash
set -euo pipefail

postgres_image=postgres:16-alpine
python_image=python:3.12-slim

script=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/restore-test.sh
source_container=numer_selftest_pg_$$
workdir=$(mktemp -d)
log=$workdir/restore-tests.log
status=0
line=""

cleanup() {
  local found
  found=$(docker ps -aq --filter "name=$source_container")
  [[ -z $found ]] || docker rm -f -v "$source_container" >/dev/null
  rm -rf "$workdir"
}
trap cleanup EXIT

fail() {
  printf 'FAILED: %s\n%s\n' "$1" "$line" >&2
  exit 1
}

passed() {
  printf 'passed: %s\n' "$1"
}

restore() {
  local kind=$1 directory=$2 image=$postgres_image
  [[ $kind == postgres ]] || image=$python_image
  status=0
  bash "$script" --name selftest --kind "$kind" --backup-dir "$directory" --pattern '*.backup' \
    --image "$image" --log "$log" >"$workdir/output.txt" 2>&1 || status=$?
  line=$(tail -n 1 "$log")
}

expect_pass() {
  [[ $status -eq 0 && $line == *" result=PASS "* ]] || {
    cat "$workdir/output.txt" >&2
    fail "$1"
  }
}

expect_fail() {
  [[ $status -eq 1 && $line == *" result=FAIL reason=$2"* ]] || {
    cat "$workdir/output.txt" >&2
    fail "$1"
  }
}

source_query() {
  docker exec "$source_container" psql -U postgres -d source -v ON_ERROR_STOP=1 -qc "$1"
}

make_dump() {
  local attempt
  docker run -d --name "$source_container" --network none \
    -e POSTGRES_HOST_AUTH_METHOD=trust "$postgres_image" >/dev/null
  for ((attempt = 0; attempt < 60; attempt++)); do
    if docker exec "$source_container" pg_isready -q -h localhost -U postgres; then
      break
    fi
    sleep 1
  done
  docker exec "$source_container" createdb -U postgres source
  source_query "create table notes (id int primary key); insert into notes values (1), (2), (3)"
  source_query "create table alembic_version (version_num text); insert into alembic_version values ('selftest0001')"
  docker exec "$source_container" pg_dump -U postgres -d source --format custom --no-owner >"$1"
  docker rm -f -v "$source_container" >/dev/null
}

make_sqlite() {
  docker run --rm --network none --user "$(id -u):$(id -g)" -v "$1:/t" "$python_image" python -c \
    'import sqlite3; db = sqlite3.connect("/t/good.backup"); db.execute("PRAGMA journal_mode = WAL"); db.execute("create table notes (id integer primary key)"); db.executemany("insert into notes values (?)", [(1,), (2,), (3,)]); db.commit(); db.close()'
}

mkdir "$workdir/postgres" "$workdir/sqlite" "$workdir/random" "$workdir/old"

dump=$workdir/postgres/good.backup
make_dump "$dump"
checksum=$(sha256sum "$dump")
# modules record the path inside their backup container, which does not exist on the host
printf '%s  /backups/good.backup\n' "${checksum%% *}" >"$dump.sha256"
restore postgres "$workdir/postgres"
expect_pass "a good dump did not pass"
[[ $line == *" tables=2 revision=selftest0001 "* ]] || fail "wrong table count or revision"
grep -qx 'table=notes rows=3' "$workdir/output.txt" || fail "wrong row count"
passed "1/6 a good postgres dump passes with tables=2 and its revision"

size=$(wc -c <"$dump")
head -c "$((size / 2))" "$dump" >"$workdir/truncated"
mv "$workdir/truncated" "$dump"
restore postgres "$workdir/postgres"
expect_fail "a truncated dump with a checksum did not fail" "checksum mismatch"
rm "$dump.sha256"
restore postgres "$workdir/postgres"
expect_fail "a truncated dump without a checksum did not fail" "pg_restore failed"
passed "2/6 a truncated postgres dump fails, with and without a checksum file"

make_sqlite "$workdir/sqlite"
restore sqlite "$workdir/sqlite"
expect_pass "a good sqlite file did not pass"
[[ $line == *" tables=1 revision=none "* ]] || fail "wrong sqlite table count"
grep -qx 'table=notes rows=3' "$workdir/output.txt" || fail "wrong sqlite row count"
passed "3/6 a good sqlite file passes"

head -c 8192 /dev/urandom >"$workdir/random/random.backup"
restore sqlite "$workdir/random"
expect_fail "random bytes did not fail" "sqlite check failed"
passed "4/6 a file of random bytes fails as sqlite"

cp "$workdir/sqlite/good.backup" "$workdir/old/old.backup"
touch -d 2020-01-01T00:00:00Z "$workdir/old/old.backup"
restore sqlite "$workdir/old"
expect_fail "an old backup did not fail" "backup is older than 26 hours"
passed "5/6 a backup older than the maximum age fails"

containers=$(docker ps -aq --filter name=restore_)
networks=$(docker network ls -q --filter name=restore_net_)
[[ -z $containers && -z $networks ]] || fail "containers or networks were left behind"
[[ $(wc -l <"$log") -eq 6 ]] || fail "the log does not hold one line per run"
passed "6/6 every run logged one line and left no container or network"
