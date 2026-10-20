#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
work=$(mktemp -d)
server_pid=""
monitor_pid=""

cleanup() {
  [[ -z $monitor_pid ]] || stop "$monitor_pid"
  [[ -z $server_pid ]] || stop "$server_pid"
  rm -rf "${work:?}"
}

stop() {
  if kill -0 "$1" 2>/dev/null; then
    kill "$1"
    wait "$1" 2>/dev/null || [[ $? -eq 143 ]]
  fi
}

pass() {
  echo "passed: $1"
}

fail() {
  echo "failed: $1" >&2
  for output in messages monitor.log; do
    echo "--- $output" >&2
    [[ ! -f $work/$output ]] || cat "$work/$output" >&2
  done
  exit 1
}

wait_until() {
  local attempt
  for ((attempt = 0; attempt < 600; attempt++)); do
    if "$@"; then
      return 0
    fi
    sleep 0.1
  done
  return 1
}

lines() {
  if [[ -f $1 ]]; then
    wc -l <"$1" | tr -d ' '
  else
    echo 0
  fi
}

heartbeats_reach() {
  [[ $(lines "$work/heartbeats") -ge $1 ]]
}

wait_loops() {
  wait_until heartbeats_reach $(($(lines "$work/heartbeats") + $1)) || fail "the monitor stopped looping"
}

has_message() {
  [[ -f $work/messages ]] && grep -qxF "{\"text\":\"$1\"}" "$work/messages"
}

count_messages() {
  [[ -f $work/messages ]] || {
    echo 0
    return
  }
  grep -cF "$1" "$work/messages" || [[ $? -eq 1 ]]
}

log_line() {
  echo "$1 name=$2 file=$2.dump seconds=1 tables=1 revision=none result=$3 reason=-"
}

trap cleanup EXIT

cat >"$work/server.py" <<'PY'
import http.server
import pathlib
import sys

work = pathlib.Path(sys.argv[1])


def append(name, text):
    with open(work / name, "a") as out:
        out.write(text + "\n")


class Handler(http.server.BaseHTTPRequestHandler):
    def reply(self, status):
        self.send_response(status)
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        name = self.path.strip("/")
        if name == "heartbeat":
            append("heartbeats", name)
        if (work / f"down_{name}").exists():
            append("failed_checks", name)
            return self.reply(503)
        self.reply(200)

    def do_POST(self):
        body = self.rfile.read(int(self.headers["Content-Length"])).decode()
        if (work / "reject").exists():
            (work / "reject").unlink()
            append("rejected", f"{len((work / 'failed_checks').read_text().split())} {body}")
            return self.reply(500)
        append("messages", body)
        self.reply(200)

    def log_message(self, *args):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
(work / "port.tmp").write_text(str(server.server_port))
(work / "port.tmp").rename(work / "port")
server.serve_forever()
PY

python3 -I "$work/server.py" "$work" &
server_pid=$!
wait_until test -f "$work/port" || fail "the fake server did not start"
base=http://127.0.0.1:$(<"$work/port")

mkdir "$work/backups"
touch "$work/backups/muto.dump"
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for label in muto events_bot clavis; do
  log_line "$now" "$label" PASS
done >"$work/restore.log"

env CHECKS="muto|$base/muto
clavis|$base/clavis" \
  BACKUPS="muto|$work/backups|26" \
  RESTORE_LOG="$work/restore.log" \
  RESTORE_NAMES="muto events_bot clavis" \
  ALERT_WEBHOOK_URL="$base/webhook" \
  HEARTBEAT_URL="$base/heartbeat" \
  INTERVAL_SECONDS=1 \
  STATE_DIR="$work/state" \
  sh "$root/monitor.sh" >"$work/monitor.log" 2>&1 &
monitor_pid=$!

wait_loops 4
[[ $(lines "$work/messages") -eq 0 ]] || fail "a message was sent while everything was healthy"
pass "no message while both modules are healthy"

touch "$work/reject" "$work/down_muto"
wait_until has_message "DOWN muto" || fail "no DOWN message"
[[ $(count_messages DOWN) -eq 1 && $(lines "$work/messages") -eq 1 ]] || fail "expected exactly one DOWN message"
read -r failed_before_alert _ <"$work/rejected"
[[ $failed_before_alert -eq 3 ]] || fail "DOWN was sent after $failed_before_alert failures instead of 3"
pass "exactly one DOWN message after three failures"

wait_loops 4
[[ $(count_messages DOWN) -eq 1 ]] || fail "DOWN was repeated inside the repeat window"
pass "no second DOWN inside the repeat window"

rm "${work:?}/down_muto"
wait_until has_message "RECOVERED muto" || fail "no RECOVERED message"
pass "RECOVERED after the module came back"

# these are only seen on the next thirtieth loop
touch -t 202001010000 "$work/backups/muto.dump"
{
  log_line "$now" muto PASS
  log_line "$now" muto FAIL
  log_line 2020-01-01T00:00:00Z events_bot PASS
} >"$work/restore.log"

wait_until has_message "BACKUP STALE muto" || fail "no BACKUP STALE message"
pass "BACKUP STALE for an old newest file"

for expected in "muto failed" "events_bot stale" "clavis missing"; do
  wait_until has_message "RESTORE TEST $expected" || fail "no RESTORE TEST $expected message"
done
pass "RESTORE TEST for a failed, a stale and a missing label"

[[ $(lines "$work/heartbeats") -gt 0 ]] || fail "the heartbeat was never called"
pass "the heartbeat endpoint was called"

[[ $(lines "$work/rejected") -eq 1 ]] || fail "the webhook never returned 500"
kill -0 "$monitor_pid" 2>/dev/null || fail "the monitor stopped after the webhook returned 500"
pass "the monitor is still running after a webhook 500"
