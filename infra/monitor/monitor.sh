#!/bin/sh
set -eu

: "${CHECKS:?}"
BACKUPS=${BACKUPS:-}
RESTORE_NAMES=${RESTORE_NAMES:-}
RESTORE_MAX_AGE_DAYS=${RESTORE_MAX_AGE_DAYS:-8}
ALERT_WEBHOOK_URL=${ALERT_WEBHOOK_URL:-}
HEARTBEAT_URL=${HEARTBEAT_URL:-}
INTERVAL_SECONDS=${INTERVAL_SECONDS:-60}
REPEAT_HOURS=${REPEAT_HOURS:-6}
STATE_DIR=${STATE_DIR:-/tmp/state}

queued=0

send() {
  printf '%s\n' "$1"
  [ -n "$ALERT_WEBHOOK_URL" ] || return 0
  queued=$((queued + 1))
  printf '%s' "$1" >"$STATE_DIR/outbox/$(printf '%012d' "$queued")"
}

flush() {
  for message in "$STATE_DIR"/outbox/*; do
    [ -f "$message" ] || return 0
    # an undelivered message stays queued, so order is kept and the next loop retries
    curl -fsS --max-time 10 -o /dev/null -H 'Content-Type: application/json' \
      --data "{\"text\":\"$(cat "$message")\"}" "$ALERT_WEBHOOK_URL" || return 0
    rm "${message:?}"
  done
}

alert() {
  now=$(date +%s)
  if [ -f "$STATE_DIR/$1.alert" ] &&
    [ $((now - $(cat "$STATE_DIR/$1.alert"))) -lt $((REPEAT_HOURS * 3600)) ]; then
    return 0
  fi
  send "$2"
  printf '%s\n' "$now" >"$STATE_DIR/$1.alert"
}

recover() {
  [ -f "$STATE_DIR/$1.alert" ] || return 0
  send "$2"
  rm "${STATE_DIR:?}/${1:?}.alert"
}

check_http() {
  while IFS='|' read -r name url; do
    [ -n "$name" ] || continue
    failures=$STATE_DIR/http_$name.failures
    if curl -fsS --max-time 10 -o /dev/null "$url"; then
      rm -f "${failures:?}"
      recover "http_$name" "RECOVERED $name"
      continue
    fi
    count=0
    [ ! -f "$failures" ] || count=$(cat "$failures")
    count=$((count + 1))
    printf '%s\n' "$count" >"$failures"
    [ "$count" -lt 3 ] || alert "http_$name" "DOWN $name"
  done <<LIST
$CHECKS
LIST
}

check_backups() {
  while IFS='|' read -r name directory hours; do
    [ -n "$name" ] || continue
    # a directory that cannot be read counts as stale
    if recent=$(find "$directory/" -maxdepth 1 -type f -mmin "-$((hours * 60))") && [ -n "$recent" ]; then
      recover "backup_$name" "RECOVERED BACKUP $name"
    else
      alert "backup_$name" "BACKUP STALE $name"
    fi
  done <<LIST
$BACKUPS
LIST
}

# date cannot parse this format the same way on busybox, gnu and bsd
epoch() {
  printf '%s\n' "$1" | awk -F '[-T:Z]' '{
    y = $1; m = $2
    if (m < 3) { y--; m += 12 }
    days = 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + $3 - 1 - 719468
    printf "%d\n", days * 86400 + $4 * 3600 + $5 * 60 + $6
  }'
}

restore_problem() {
  # a log that cannot be read reports every label as missing
  line=$(awk -v want="name=$1" '$2 == want { last = $0 } END { print last }' "$RESTORE_LOG") || line=
  if [ -z "$line" ]; then
    echo missing
    return 0
  fi
  case $line in
  *" result=PASS "*) ;;
  *)
    echo failed
    return 0
    ;;
  esac
  age=$(($(date +%s) - $(epoch "${line%% *}")))
  [ "$age" -lt $((RESTORE_MAX_AGE_DAYS * 86400)) ] || echo stale
}

check_restores() {
  for label in $RESTORE_NAMES; do
    problem=$(restore_problem "$label")
    if [ -z "$problem" ]; then
      recover "restore_$label" "RECOVERED RESTORE TEST $label"
    else
      alert "restore_$label" "RESTORE TEST $label $problem"
    fi
  done
}

[ -z "$RESTORE_NAMES" ] || : "${RESTORE_LOG:?}"
mkdir -p "$STATE_DIR/outbox"

loop=0
while :; do
  check_http
  if [ $((loop % 30)) -eq 0 ]; then
    check_backups
    check_restores
  fi
  flush
  if [ -n "$HEARTBEAT_URL" ]; then
    # the heartbeat service notices missed pings itself
    curl -fsS --max-time 10 -o /dev/null "$HEARTBEAT_URL" || :
  fi
  loop=$((loop + 1))
  sleep "$INTERVAL_SECONDS"
done
