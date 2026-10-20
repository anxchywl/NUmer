# Monitor

`monitor.sh` checks the module APIs, the age of the backups and the restore-test log, posts
failures and recoveries to a webhook and pings an outside heartbeat. It runs as its own
Compose project, `numer-monitor`.

## What it watches

| Check | How often | Alert | Recovery |
|---|---|---|---|
| each `CHECKS` URL answers within 10 seconds without an error status | every loop, alerts after 3 failures in a row | `DOWN <name>` | `RECOVERED <name>` |
| the newest file of each `BACKUPS` directory is young enough | every 30 loops | `BACKUP STALE <name>` | `RECOVERED BACKUP <name>` |
| the last restore-test log line of each label is a recent `PASS` | every 30 loops | `RESTORE TEST <label> <failed\|stale\|missing>` | `RECOVERED RESTORE TEST <label>` |

An alert repeats every `REPEAT_HOURS` while the problem lasts. A message the webhook did not
accept is kept and sent again on the next loop. Every message is also printed to the
container log, which can name hosts in `curl` errors. Messages carry no URL or path.

The heartbeat is pinged after every loop. The outside service must alert you when pings stop:
that is the only sign of a dead server or a dead monitor. It says nothing about whether the
webhook works.

It does not check container state, disk space or the content of any backup.

## Variables

All of them go in `monitor.env`, copied from `monitor.env.example`.

| Variable | Default | Meaning |
|---|---|---|
| `CHECKS` | required | lines `name\|url` |
| `BACKUPS` | none | lines `name\|directory\|max age hours` |
| `RESTORE_LOG` | required with `RESTORE_NAMES` | restore-test log path |
| `RESTORE_NAMES` | none | space-separated labels expected in the log |
| `RESTORE_MAX_AGE_DAYS` | `8` | oldest acceptable `PASS` |
| `ALERT_WEBHOOK_URL` | none | receives `POST` with JSON `{"text": "..."}` |
| `HEARTBEAT_URL` | none | pinged after every loop |
| `INTERVAL_SECONDS` | `60` | pause between loops |
| `REPEAT_HOURS` | `6` | time between repeated alerts |
| `STATE_DIR` | `/tmp/state` | alert state and unsent messages, lost when the container restarts |

Names and labels may use letters, digits, `.`, `-` and `_`. Keep the quotes around values
with several lines.

Compose also needs `MUTO_BACKUP_DIR`, `EVENTS_BOT_BACKUP_DIR`, `CLAVIS_BACKUP_DIR` and
`RESTORE_LOG_DIR`, the host directories mounted read-only. In `BACKUPS` and `RESTORE_LOG`
use the paths inside the container, as the example does.

## Start

Copy `infra/monitor/` to the server and run these from that directory.

```bash
cp monitor.env.example monitor.env
```

```bash
chmod 600 monitor.env
```

Fill in every `<...>` placeholder. The container runs as an unprivileged user, so each
mounted directory needs search and read permission for others, and the log file read
permission. Backup files themselves need no read permission, only their names and times are
read.

```bash
sudo docker compose --env-file monitor.env up -d
```

```bash
sudo docker compose --env-file monitor.env logs --tail 20
```

A `BACKUP STALE` or `RESTORE TEST ... missing` right after the start with `Permission denied`
in the log means the permissions above are not met. After changing `monitor.env`, run
`up -d` again. After changing only `monitor.sh`, add `--force-recreate`.

Once this monitor runs, stop the previous Muto-only monitor container so that Muto is not
reported twice. Find its name with `sudo docker ps`, then:

```bash
sudo docker stop <old monitor container>
```

Remove its service from the Muto deployment too, or the next Muto deploy may start it again.

## Test an alert by hand

Send a message through the real webhook:

```bash
sudo docker compose --env-file monitor.env exec monitor sh -c 'curl -fsS --max-time 10 -H "Content-Type: application/json" --data "{\"text\":\"monitor test\"}" "$ALERT_WEBHOOK_URL"'
```

Then test the whole path: stop one module API for 4 minutes. `DOWN <name>` should arrive
after about 3 minutes, and `RECOVERED <name>` within about a minute of starting it again.
Pause the monitor for longer than the heartbeat service's grace period to check that the
service alerts you, then start it again.

## Self-test

Needs `sh`, `curl` and `python3`. It talks only to a fake server on localhost and takes
under a minute.

```bash
bash infra/monitor/test/run.sh
```
