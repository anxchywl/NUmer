# P2-10: One monitor and an outside heartbeat

**Recommended model:** sonnet   **Effort:** medium
**Risk:** low   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P2-08

## Goal
Only one of the four module backends has any alerting, and it never reports recovery or
repeats. Write one small monitor that checks every module API, the age of every backup and
the restore-test log, reports failures and recoveries to a webhook, and pings an outside
heartbeat so that a dead server is noticed too.

## Read first
- `AGENTS.md`
- `infra/backup/README.md` and `infra/backup/restore-test.sh` (the log line format)
- `docs/numer2/RESEARCH.md` section 9.3

## Context
- Health paths: each module answers `GET /health/ready` with 200 when healthy.
- The monitor runs in the image `curlimages/curl:8.17.0`, which has `curl` and a POSIX `sh`
  (BusyBox), not bash.
- Alerts go to a webhook that accepts `POST` with JSON `{"text": "..."}`.
- Restore-test log lines look like
  `<ISO time> name=<label> file=... seconds=... tables=... revision=... result=PASS reason=-`.
- The server is small: the container gets 64 MB and a read-only root.
- Nothing in the repo may contain a real URL of the owner's services.

## Steps
1. `infra/monitor/monitor.sh` (`#!/bin/sh`, `set -eu`), configured only by environment:
   - `CHECKS`: lines `name|url`;
   - `BACKUPS`: lines `name|directory|max age hours` (directories are mounted read-only);
   - `RESTORE_LOG` and `RESTORE_MAX_AGE_DAYS` (default 8), `RESTORE_NAMES`: space-separated
     labels expected in the log;
   - `ALERT_WEBHOOK_URL`, `HEARTBEAT_URL` (both optional), `INTERVAL_SECONDS` (default 60),
     `REPEAT_HOURS` (default 6).
   Loop every interval:
   - each HTTP check: `curl -fsS --max-time 10`; keep a consecutive-failure count per name in
     `/tmp/state`; at 3 consecutive failures send `DOWN <name>`; while it stays down send again
     every `REPEAT_HOURS`; on the first success after an alert send `RECOVERED <name>`;
   - every 30 loops: each backup directory's newest file must be younger than its limit, else
     `BACKUP STALE <name>` (same repeat and recovery rules);
   - every 30 loops: for each label in `RESTORE_NAMES`, the newest log line with that
     `name=` must say `result=PASS` and be younger than the limit, else
     `RESTORE TEST <name>` with the reason `failed`, `stale` or `missing`;
   - after each loop, `curl` the heartbeat URL if set (a failure to reach it is ignored).
   A failed webhook post is retried on the next loop and never stops the loop. Messages contain
   the check name and the kind of problem only: no URL, no path.
2. `infra/monitor/compose.yml`: project name `numer-monitor`; one service on
   `curlimages/curl:8.17.0` running the script mounted read-only; `env_file: monitor.env`;
   `read_only: true`, `tmpfs: /tmp`, `cap_drop: [ALL]`, `security_opt:
   [no-new-privileges:true]`, `mem_limit: 64m`, `restart: unless-stopped`; read-only bind
   mounts for the backup directories and the restore log, given as variables with no default.
   No published port, no Docker socket.
   `infra/monitor/monitor.env.example`: every variable with placeholder values such as
   `gradus|https://<gradus api domain>/health/ready`.
3. `infra/monitor/test/run.sh` (bash; needs Docker or a local `sh` and `python3`): starts a
   tiny local HTTP server for two fake modules and one fake webhook that records what it
   receives; runs `monitor.sh` with `INTERVAL_SECONDS=1`; asserts: no message while both are
   healthy; after one module fails three times exactly one `DOWN` message; no second `DOWN`
   within the repeat window; a `RECOVERED` message after it comes back; a `BACKUP STALE`
   message for a directory whose newest file is too old; a `RESTORE TEST` message for a log
   whose last line for a label says `result=FAIL`; the heartbeat endpoint was called; the
   monitor is still running after the webhook returned 500 once.
4. `infra/monitor/README.md`: what it watches, the variables, how to start it, how to test an alert by hand, and that the previous Muto-only monitor container should be stopped once this one runs. Add `infra/monitor/test/run.sh` to the CI `infra` job.

## Non-goals
- Do not use bash features in `monitor.sh` (it runs under BusyBox `sh`).
- Do not read container state through the Docker socket.
- Do not add Prometheus, Grafana or any other service.
- Do not put a real URL, token or chat id in the repo.

## Constraints
- No file may contain a server address, a real domain that is not already public in a module repo, a credential or a key.
- Scripts are POSIX-friendly bash with `set -euo pipefail`, pass `shellcheck`, and never act on production data by default.
- The executor does not connect to any server. The deliverable is code and documentation that the owner runs.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- `monitor.sh` passes `shellcheck -s sh`.

## Acceptance criteria
- [ ] `shellcheck -s sh infra/monitor/monitor.sh` and `shellcheck infra/monitor/test/run.sh` exit 0.
- [ ] `bash infra/monitor/test/run.sh` exits 0 and prints each of its eight assertions as passed.
- [ ] `docker compose -f infra/monitor/compose.yml --env-file infra/monitor/monitor.env.example config -q` exits 0.
- [ ] `grep -rnE "https?://[a-z0-9.-]+\.[a-z]{2,}" infra/monitor | grep -v "<"` prints nothing.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Approval needed: choose the alert channel and the heartbeat service, fill `monitor.env` on the server, start the monitor, stop the old one, and test by stopping one API for four minutes (`docs/numer2/USER_ACTIONS.md` D-6).

## Deliverable
Branch `numer2/p2-10-monitor`, one commit, message `feat: add unified monitor with recovery and heartbeat` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- BusyBox `sh` lacks a feature the loop needs (`date` arithmetic, `find -mmin`): report what is missing before switching images.
