# P2-08: Backup restore tests

**Recommended model:** sonnet   **Effort:** medium
**Risk:** low   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P2-09

## Goal
Three module databases (Muto and EventsBot on Postgres, Clavis on SQLite) are backed up
daily, but nobody has ever proven that a backup restores. Write a script the owner can run
on a timer that restores the newest backup into a throwaway container, checks it, logs one
line, and can never touch production data.

## Read first
- `AGENTS.md`
- `docs/numer2/RESEARCH.md` section 9.3
- `scripts/verify.sh`, `.github/workflows/ci.yml`

## Context
- Backups as the module repos produce them:
  - Muto: `pg_dump --format custom --no-owner`, files `*.dump` with a sibling `*.sha256`;
    an encrypted copy `*.dump.age` may exist next to it.
  - EventsBot: `pg_dump -Fc`, custom-format files, no checksum file.
  - Clavis: a copy of the SQLite database file, 14 kept.
  Exact file names and directories differ per server, so they are arguments, not constants.
- Both Postgres modules use Alembic and have an `alembic_version` table.
- The server is small. The scratch database must not use much memory: data on a tmpfs of
  256 MB, and the container limited to 256 MB.
- The existing `restore.sh` scripts in the module repos restore over production. This
  script must be impossible to point at a running database: it only ever creates its own
  containers on its own internal network and removes them.
- This repo has no `infra/` directory yet.

## Steps
1. Create `infra/backup/restore-test.sh`. Usage:
   `restore-test.sh --name <label> --kind <postgres|sqlite> --backup-dir <dir> --pattern <glob>
   --image <docker image> [--max-age-hours 26] [--log <file>] [--decrypt-key <age key file>]`.
   Defaults: `--max-age-hours 26`, `--log /var/log/numer/restore-tests.log`.
   Behaviour common to both kinds:
   - pick the newest file in `--backup-dir` matching `--pattern`; none found is a failure;
   - fail if it is older than `--max-age-hours`;
   - if a file `<name>.sha256` exists beside it, verify it with `sha256sum -c`;
   - if the file ends in `.age`, decrypt it with `age -d -i <key>` into a private temp
     directory (mode 700) and continue with the result; without `--decrypt-key` that is a
     failure;
   - always append exactly one line to the log:
     `<ISO time> name=<label> file=<basename> seconds=<n> tables=<n> revision=<value or none> result=<PASS|FAIL> reason=<short text or ->`;
   - exit 0 on PASS and 1 on FAIL;
   - a `trap` removes the container, the network and the temp directory on every exit path.
2. `--kind postgres`:
   1. `docker network create --internal restore_net_<pid>`;
   2. `docker run -d --name restore_pg_<pid> --network restore_net_<pid> --memory 256m
      --tmpfs /var/lib/postgresql/data:rw,size=256m -e POSTGRES_PASSWORD=<random>
      -v <dir of the file>:/backups:ro <image>`; wait for `pg_isready` up to 60 seconds;
   3. `createdb -U postgres restore_target`, then time
      `pg_restore -U postgres -d restore_target --no-owner --exit-on-error --single-transaction /backups/<file>`;
   4. count base tables in schema `public` and run `select count(*)` on each; a restore with
      zero tables is a failure;
   5. read `select version_num from alembic_version` if the table exists.
3. `--kind sqlite`: copy the file to the temp directory and run, in
   `docker run --rm --network none --memory 128m -v <temp>:/t:ro <image>`, a Python one-liner
   (`python -c`) that opens `/t/<file>` read-only, runs `PRAGMA integrity_check` (must return
   `ok`), counts tables and rows per table. Zero tables is a failure. The image argument is the
   module's own backend image, which contains Python.
4. `infra/backup/test/run.sh`: a self-test that needs only Docker. It creates a Postgres
   container, makes a database with one table and three rows and an `alembic_version` row,
   dumps it in custom format into a temp directory with a `.sha256` file, removes that
   container, runs `restore-test.sh` on the dump and asserts: exit 0, the log line says
   `result=PASS`, `tables=2`, the revision value. Then it corrupts the dump (truncate to half)
   and asserts exit 1 and `result=FAIL`. Then it makes a small SQLite file with Python in a
   container and asserts PASS for `--kind sqlite`, and FAIL for a file of random bytes. Then it
   asserts FAIL for a file older than the maximum age (`touch -d`).
5. `infra/backup/README.md`: what the script proves and does not prove; the arguments; one
   example invocation per module with placeholder directories (`<muto backup dir>`); a systemd
   service and timer example that runs the three tests weekly at a quiet hour, one after
   another; how to read the log; what to do on FAIL; the monthly drill from the offsite copy
   with the offline key. No server address, no real path that is not already public in a module
   repo.
6. Add a CI job `infra` in `.github/workflows/ci.yml` running `shellcheck` on `infra/**/*.sh` and `infra/backup/test/run.sh` (the runner has Docker). Add `shellcheck infra/**/*.sh` to `scripts/verify.sh` only when `shellcheck` is installed (skip with a printed note otherwise).

## Non-goals
- Do not accept a database host, port or URL as an argument, anywhere.
- Do not modify or delete any backup file.
- Do not restore into any existing container.
- Do not change the module repos' backup scripts.
- Do not publish a port or mount the Docker socket.

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
- The script works with bash 5 on Ubuntu 24.04 and needs only `docker`, `sha256sum`, `find`, `date`, and optionally `age`.

## Acceptance criteria
- [ ] `shellcheck infra/backup/restore-test.sh infra/backup/test/run.sh` exits 0.
- [ ] `bash infra/backup/test/run.sh` exits 0 and prints each of its six assertions as passed.
- [ ] After the self-test, `docker ps -a --filter name=restore_` and `docker network ls --filter name=restore_net_` print no rows.
- [ ] `grep -rnE "([0-9]{1,3}\.){3}[0-9]{1,3}" infra` prints nothing.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Approval needed: copy `infra/backup/` to the server, run the test once by hand per module, then enable the weekly timer (`docs/numer2/USER_ACTIONS.md` D-5).

## Deliverable
Branch `numer2/p2-08-restore-tests`, one commit, message `feat: add backup restore test script` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- Docker is not available to run the self-test.
- A module's backup format cannot be restored by `pg_restore` in custom format (then that module needs its own kind).
