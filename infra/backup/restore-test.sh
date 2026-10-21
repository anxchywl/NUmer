#!/usr/bin/env bash
set -euo pipefail

usage="usage: restore-test.sh --name <label> --kind <postgres|sqlite> --backup-dir <dir> --pattern <glob> --image <docker image> [--max-age-hours 26] [--log <file>] [--decrypt-key <age key file>]"

name=""
kind=""
backup_dir=""
pattern=""
image=""
max_age_hours=26
log=/var/log/numer/restore-tests.log
key=""

file=""
base=-
workdir=""
network=""
seconds=0
tables=0
revision=none
result=FAIL
reason="unexpected error"

fail() {
  reason=$1
  exit 1
}

remove_container() {
  local cid found
  [[ -s $workdir/cid ]] || return 0
  cid=$(<"$workdir/cid")
  found=$(docker ps -aq --no-trunc --filter "id=$cid") || return 1
  [[ -n $found ]] || return 0
  docker rm -f -v "$cid" >/dev/null
}

cleanup() {
  local leftover=""
  if [[ -n $workdir ]]; then
    remove_container || leftover="container"
  fi
  if [[ -n $network ]]; then
    docker network rm "$network" >/dev/null || leftover="$leftover network"
  fi
  if [[ -n $workdir ]]; then
    rm -rf "$workdir" || leftover="$leftover temp directory"
  fi
  [[ -z $leftover ]] && return 0
  result=FAIL
  reason="cleanup failed: ${leftover# }"
}

finish() {
  local status=0 line
  trap - EXIT
  cleanup
  line="$(date -u +%Y-%m-%dT%H:%M:%SZ) name=${name:--} file=$base seconds=$seconds tables=$tables revision=$revision result=$result reason=$reason"
  printf '%s\n' "$line"
  if ! { mkdir -p "$(dirname "$log")" && printf '%s\n' "$line" >>"$log"; }; then
    echo "cannot write the log file $log" >&2
    status=1
  fi
  [[ $result == PASS ]] || status=1
  exit "$status"
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    [[ $# -ge 2 ]] || fail "missing value for $1"
    case $1 in
    --name) name=$2 ;;
    --kind) kind=$2 ;;
    --backup-dir) backup_dir=$2 ;;
    --pattern) pattern=$2 ;;
    --image) image=$2 ;;
    --max-age-hours) max_age_hours=$2 ;;
    --log) log=$2 ;;
    --decrypt-key) key=$2 ;;
    *) fail "unknown argument $1" ;;
    esac
    shift 2
  done
}

check_arguments() {
  if [[ -z $name || -z $kind || -z $backup_dir || -z $pattern || -z $image ]]; then
    echo "$usage" >&2
    fail "a required argument is missing"
  fi
  [[ $name =~ ^[A-Za-z0-9_.-]+$ ]] || fail "name may hold only letters, digits, dot, dash and underscore"
  [[ $kind == postgres || $kind == sqlite ]] || fail "kind must be postgres or sqlite"
  [[ $max_age_hours =~ ^[0-9]+$ ]] || fail "max age must be a whole number of hours"
}

pick_newest() {
  local candidate
  [[ -d $backup_dir && -r $backup_dir && -x $backup_dir ]] || fail "backup directory is not readable"
  backup_dir=$(cd "$backup_dir" && pwd)
  while IFS= read -r -d '' candidate; do
    if [[ -z $file || $candidate -nt $file ]]; then
      file=$candidate
    fi
  done < <(find "$backup_dir" -maxdepth 1 -type f -name "$pattern" -print0)
  [[ -n $file ]] || fail "no backup matches the pattern"
  base=${file##*/}
}

check_age() {
  local recent
  recent=$(find "$file" -mmin "-$((10#$max_age_hours * 60))") || fail "cannot read the backup age"
  [[ -n $recent ]] || fail "backup is older than $max_age_hours hours"
}

check_checksum() {
  local expected
  [[ -f $file.sha256 ]] || return 0
  read -r expected _ <"$file.sha256" || fail "cannot read the checksum file"
  # the recorded path is the one inside the backup container, so only the hash is reused
  printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null || fail "checksum mismatch"
}

decrypt() {
  [[ $file == *.age ]] || return 0
  [[ -n $key ]] || fail "encrypted backup needs --decrypt-key"
  local plain=$workdir/${base%.age}
  age -d -i "$key" -o "$plain" "$file" || fail "decryption failed"
  file=$plain
}

query() {
  docker exec "restore_pg_$$" psql -U postgres -d restore_target -v ON_ERROR_STOP=1 -Atc "$1"
}

wait_for_postgres() {
  local attempt
  for ((attempt = 0; attempt < 60; attempt++)); do
    # tcp only answers once the image has finished initialising and restarted
    if docker exec "restore_pg_$$" pg_isready -q -h localhost -U postgres; then
      return 0
    fi
    sleep 1
  done
  fail "postgres was not ready after 60 seconds"
}

restore_postgres() {
  local password started status=0 names table rows versions
  password=$(head -c 32 /dev/urandom | sha256sum)

  docker network create --internal "restore_net_$$" >/dev/null || fail "cannot create the network"
  network=restore_net_$$
  # the wal settings keep a larger restore from filling the small tmpfs
  POSTGRES_PASSWORD=${password%% *} docker run -d --name "restore_pg_$$" --cidfile "$workdir/cid" \
    --network "$network" --memory 256m \
    --tmpfs /var/lib/postgresql/data:rw,size=256m \
    -e POSTGRES_PASSWORD \
    -v "$(dirname "$file"):/backups:ro" \
    "$image" postgres -c wal_level=minimal -c max_wal_senders=0 -c max_wal_size=64MB >/dev/null ||
    fail "cannot start the postgres container"
  wait_for_postgres

  docker exec "restore_pg_$$" createdb -U postgres restore_target || fail "createdb failed"
  started=$SECONDS
  docker exec "restore_pg_$$" pg_restore -U postgres -d restore_target \
    --no-owner --exit-on-error --single-transaction "/backups/${file##*/}" || status=$?
  seconds=$((SECONDS - started))
  [[ $status -eq 0 ]] || fail "pg_restore failed"

  names=$(query "select quote_ident(table_name) from information_schema.tables where table_schema = 'public' and table_type = 'BASE TABLE' order by 1") ||
    fail "cannot list the tables"
  [[ -n $names ]] || fail "the restore has no tables"
  while IFS= read -r table; do
    rows=$(query "select count(*) from public.$table") || fail "cannot count the rows of a table"
    echo "table=$table rows=$rows"
    tables=$((tables + 1))
  done <<<"$names"

  grep -qx alembic_version <<<"$names" || return 0
  versions=$(query "select string_agg(version_num, ',' order by version_num) from public.alembic_version") ||
    fail "cannot read the alembic revision"
  revision=${versions:-none}
}

check_sqlite() {
  local script output started status=0
  script='import pathlib, sqlite3, sys; db = sqlite3.connect(pathlib.Path("/t", sys.argv[1]).as_uri() + "?mode=ro&immutable=1", uri=True); check = db.execute("PRAGMA integrity_check").fetchone()[0]; check == "ok" or sys.exit("integrity check: " + check); names = [r[0] for r in db.execute("select name from sqlite_master where type = ? and name not like ? order by name", ("table", "sqlite_%"))]; print(len(names)); [print("table=%s rows=%d" % (n, db.execute("select count(*) from \"%s\"" % n.replace("\"", "\"\"")).fetchone()[0])) for n in names]'

  mkdir "$workdir/sqlite"
  cp "$file" "$workdir/sqlite/" || fail "cannot copy the backup"

  started=$SECONDS
  # the image's own user could not read the private temp directory
  output=$(docker run --rm --name "restore_sqlite_$$" --cidfile "$workdir/cid" \
    --network none --memory 128m --user "$(id -u):$(id -g)" --entrypoint python \
    -v "$workdir/sqlite:/t:ro" "$image" -c "$script" "${file##*/}") || status=$?
  seconds=$((SECONDS - started))
  [[ $status -eq 0 ]] || fail "sqlite check failed"

  tables=${output%%$'\n'*}
  [[ $tables -gt 0 ]] || fail "the database has no tables"
  printf '%s\n' "${output#*$'\n'}"
}

trap finish EXIT
trap 'fail interrupted' HUP INT TERM

parse_arguments "$@"
check_arguments
pick_newest
check_age
check_checksum
workdir=$(mktemp -d) || fail "cannot create a temp directory"
chmod 700 "$workdir"
decrypt
case $kind in
postgres) restore_postgres ;;
sqlite) check_sqlite ;;
esac
result=PASS
reason=-
