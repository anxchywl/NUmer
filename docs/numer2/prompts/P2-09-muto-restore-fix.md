# P2-09: Muto: fix the restore script and Caddyfile

**Recommended model:** sonnet   **Effort:** low
**Risk:** low   **Est.:** 1 h
**Repo / working dir:** Muto (`anxchywl/Muto`) @ the default branch   **Depends on:** none

## Goal
Muto's disaster-restore script and its dedicated Caddyfile refer to a compose service named
`backend`, which does not exist: the service is `muto-api`. The restore script therefore
fails halfway through a real restore. Fix the names.

## Read first
- `AGENTS.md` (this repo's rules are binding)
- `docker/docker-compose.production.yml`
- `deploy/restore.sh`
- `deploy/Caddyfile`
- `docs/INFRASTRUCTURE.md` (the backup and restore section)
- `.github/workflows/ci.yml` (the deployment-validation job)

## Context
- In `docker/docker-compose.production.yml` the API service and its container are named
  `muto-api`. No service or network alias is named `backend`.
- `deploy/restore.sh` runs `stop backend`, `run backend` and `up -d backend` (lines 18, 24,
  25). It takes a pre-restore backup first (line 17) and only then fails.
- `deploy/Caddyfile` line 11 proxies to `backend:8000`. That file is used only by the
  `dedicated` compose profile, which is not the one in production today.

## Steps
1. In `deploy/restore.sh` replace the service name `backend` with `muto-api` in every compose command. Read the whole script and confirm that each compose invocation names a service that exists in `docker/docker-compose.production.yml`.
2. In `deploy/Caddyfile` change the upstream to `muto-api:8000`.
3. Search the repo for other references to a service or host named `backend` in `deploy/`, `docker/` and `docs/` (`grep -rn "backend:8000\|stop backend\|up -d backend\|run .*backend" deploy docker docs`) and fix each one that means the compose service.
4. Add a test to the existing CI policy tests (the file that already checks deploy scripts, or a new `backend/tests/unit/test_deploy_names.py` if none fits): every service name used after `stop`, `run`, `up -d` or `exec` in `deploy/*.sh` exists as a service key in `docker/docker-compose.production.yml`.
5. Correct the sentence in `docs/INFRASTRUCTURE.md` that describes the restore, if it names the wrong service. Run `./scripts/verify.sh`, `shellcheck deploy/*.sh`, and `docker compose -f docker/docker-compose.production.yml config -q` with the example env file.

## Non-goals
- Do not change what the restore does or its order of steps.
- Do not rename the compose service.
- Do not touch the backup script, the monitor or the application code.
- Do not run the restore.

## Constraints
- Follow this repo's own `AGENTS.md`: layering (domain, application, infrastructure, api), settings only in `config.py`, no bare `except`, no docstrings.
- Production must refuse the development adapter and development tokens, as it does today.
- Do not log tokens, emails or personal data.
- No file may contain a server address, a real domain that is not already public in a module repo, a credential or a key.
- Scripts are POSIX-friendly bash with `set -euo pipefail`, pass `shellcheck`, and never act on production data by default.
- The executor does not connect to any server. The deliverable is code and documentation that the owner runs.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `grep -rn "backend:8000\|stop backend\|up -d backend" deploy docker` prints nothing.
- [ ] The new test passes and fails if a wrong service name is put back (try it, then revert).
- [ ] `shellcheck deploy/*.sh` exits 0.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p2-09-muto-restore-fix`, one commit, message `fix: use the real service name in restore script and caddyfile` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A network alias `backend` is defined somewhere you did not expect, so the old name was valid in some setup.
