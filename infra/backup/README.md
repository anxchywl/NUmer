# Backup restore tests

`restore-test.sh` takes the newest backup in a directory, restores it into a throwaway
container, checks the result and writes one log line.

## What it proves

- A backup matching the pattern exists and is recent enough.
- Its checksum matches, when a `.sha256` file sits beside it.
- An `.age` copy decrypts with the key you gave it.
- Postgres: the dump restores completely, in one transaction, into an empty database of the
  given image, has at least one table in schema `public`, and every such table can be read.
- SQLite: the file passes `PRAGMA integrity_check`, has at least one table, and every table
  can be read.

## What it does not prove

- That the data is correct or complete. It prints row counts but does not compare them with
  anything.
- That the application starts against the restored database, or that the Alembic revision
  matches the deployed code.
- That grants and ownership restore. `--no-owner` drops ownership, and a dump that grants
  rights to a role missing from the scratch database fails.
- That files outside the database, such as uploaded images, are backed up.
- That the offsite copy works, unless you run the monthly drill below.

It never touches a running database. It takes no host, port or URL, creates its own
container (for Postgres also its own internal network), publishes no port, mounts the
backup read-only and removes what it created on every exit it can catch.

## Requirements

Bash, `docker`, `sha256sum`, `find`, `date` and the other core utilities, plus `age` for
encrypted copies. Run it with `sudo`: it reads private backup files and writes under
`/var/log`.

The scratch Postgres has 256 MB of memory and keeps its data on a 256 MB tmpfs. A database
of about 140 MB restored in testing. One that no longer fits fails the test, usually with
`pg_restore failed`.

## Arguments

| Argument | Default | Meaning |
|---|---|---|
| `--name <label>` | required | label in the log; letters, digits, `.`, `-`, `_` |
| `--kind <postgres\|sqlite>` | required | how to restore |
| `--backup-dir <dir>` | required | directory searched, without subdirectories |
| `--pattern <glob>` | required | file name pattern; quote it |
| `--image <image>` | required | Postgres: the module's database image. SQLite: the module's backend image, which has Python |
| `--max-age-hours <n>` | `26` | oldest acceptable backup |
| `--log <file>` | `/var/log/numer/restore-tests.log` | log file, appended |
| `--decrypt-key <file>` | none | age identity file, required for a `.age` backup |

The newest file by modification time is chosen. The exit status is 0 on PASS and 1 on FAIL,
or when the log cannot be written.

## Examples

Use the same Postgres major version as the module's compose file.

Muto:

```bash
sudo bash <install dir>/restore-test.sh --name muto --kind postgres --backup-dir "<muto backup dir>" --pattern 'muto-*.dump' --image postgres:16-alpine
```

EventsBot:

```bash
sudo bash <install dir>/restore-test.sh --name events_bot --kind postgres --backup-dir "<events_bot backup dir>" --pattern 'events_bot-*.dump' --image postgres:16-alpine
```

Clavis:

```bash
sudo bash <install dir>/restore-test.sh --name clavis --kind sqlite --backup-dir "<clavis backup dir>" --pattern 'clavis-*.sqlite3' --image <clavis backend image>
```

## Weekly timer

Pick an hour when no backup, import or deploy runs. The three tests run one after another so
that only one scratch container uses memory at a time, and a failure does not skip the rest.

`/etc/systemd/system/numer-restore-test.service`:

```ini
[Unit]
Description=Restore the newest module backups into throwaway containers
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
TimeoutStartSec=30min
ExecStart=/bin/bash -c '\
  status=0; \
  bash "<install dir>/restore-test.sh" --name muto --kind postgres --backup-dir "<muto backup dir>" --pattern "muto-*.dump" --image postgres:16-alpine || status=1; \
  bash "<install dir>/restore-test.sh" --name events_bot --kind postgres --backup-dir "<events_bot backup dir>" --pattern "events_bot-*.dump" --image postgres:16-alpine || status=1; \
  bash "<install dir>/restore-test.sh" --name clavis --kind sqlite --backup-dir "<clavis backup dir>" --pattern "clavis-*.sqlite3" --image "<clavis backend image>" || status=1; \
  exit "$$status"'
```

`/etc/systemd/system/numer-restore-test.timer`:

```ini
[Unit]
Description=Weekly backup restore test

[Timer]
OnCalendar=Sun *-*-* 04:30
Persistent=true

[Install]
WantedBy=timers.target
```

Enable it only after each test has passed once by hand:

```bash
sudo systemctl daemon-reload
```

```bash
sudo systemctl enable --now numer-restore-test.timer
```

## Reading the log

```bash
sudo tail -n 3 /var/log/numer/restore-tests.log
```

```text
<ISO time> name=<label> file=<basename> seconds=<n> tables=<n> revision=<value or none> result=<PASS|FAIL> reason=<short text or ->
```

`seconds` is the time of `pg_restore`, or of the SQLite check. `revision` is the Alembic
revision, `none` for a database without one. A table count that drops between weeks is worth
a look even when the result is PASS. Row counts and error details are printed, not logged;
for timer runs read them with `journalctl -u numer-restore-test.service`.

A failed run also leaves the unit failed. Nothing sends an alert, so check the log weekly.

## When a test fails

Treat that module as having no usable backup until a test passes. Do not delete older
backups, and check that retention will not remove the last good one while you investigate.
Never run a module's `restore.sh` to investigate: it restores over production.

| Reason | Where to look |
|---|---|
| `no backup matches the pattern`, `backup directory is not readable` | the directory, the pattern, `sudo` |
| `backup is older than <n> hours` | the module's backup service and its log |
| `checksum mismatch` | disk errors, or a file changed or cut short after it was written |
| `decryption failed` | the key does not match the recipient, or the file is damaged |
| `pg_restore failed` | the printed error: a damaged dump, a version or extension the image lacks, a missing role, or no space |
| `sqlite check failed` | the printed error: a damaged file, or an image that is missing or has no `python` |
| `the restore has no tables`, `the database has no tables` | the backup job is dumping an empty or wrong database |
| `cannot create the network`, `cannot start the postgres container` | Docker itself, free memory, or a leftover with the same name |
| `cleanup failed: ...` | remove the `restore_` container or network, or the temp directory, by hand |

A run killed with `SIGKILL`, or a host that loses power, cannot clean up or log. Look for
leftovers with `docker ps -a --filter name=restore_` and
`docker network ls --filter name=restore_net_`.

Once the cause is fixed, make a new backup and run the test again.

## Monthly drill from the offsite copy

This proves the copy you would use if the host were gone. Do it on your own machine, not on
the server, so that the offline key never reaches the server.

1. Download the newest `*.dump.age` and its `.sha256` from offsite storage into an empty
   private directory.
2. Run the test with the offline key:

   ```bash
   bash infra/backup/restore-test.sh --name muto-offsite --kind postgres --backup-dir "<download dir>" --pattern 'muto-*.dump.age' --image postgres:16-alpine --decrypt-key "<offline key file>" --log "<download dir>/restore-tests.log"
   ```

3. Confirm `result=PASS`, note the date and `seconds`, then delete the download directory.

The age limit is measured from the file's modification time, which a download may set to
now, so also check the date in the file name. A module with no offsite or encrypted copy
cannot pass this drill; that is a gap to close in its own repo.

## Self-test

Needs only Docker. It pulls `postgres:16-alpine` and `python:3.12-slim` if they are missing.

```bash
bash infra/backup/test/run.sh
```
