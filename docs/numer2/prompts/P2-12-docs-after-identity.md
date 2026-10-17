# P2-12: Docs after identity and infrastructure

**Recommended model:** sonnet   **Effort:** low
**Risk:** low   **Est.:** 2 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P2-07, P2-10, P2-11

## Goal
The module backends now accept Firebase ID tokens, roles are claims, account deletions are
delivered as events, and operations scripts exist. Describe all of that once, in
`docs/INFRASTRUCTURE.md`, and point to it from the other docs.

## Read first
- `AGENTS.md`, `README.md`, `docs/INFRASTRUCTURE.md`
- `backend/numer_identity/README.md`
- `infra/RUNBOOK.md`, `infra/backup/README.md`, `infra/monitor/README.md`
- `functions/src/roles/`, `functions/src/account/`
- `docs/numer2/DECISIONS.md` D-01 to D-08

## Context
- `docs/INFRASTRUCTURE.md` owns how the system runs. `AGENTS.md` owns rules for contributors
  and the repository layout. Each fact is written once.
- Module backends live in their own repositories (Gradus, Clavis, EventsBot, Muto) and are
  described there in detail; this repo's doc gives one paragraph each and a link.
- Nothing about the server may appear: no address, hostname, provider, size or project list.

## Steps
1. `docs/INFRASTRUCTURE.md`, add:
   - `## Backends`: a table of the four module backends (purpose, storage, repository link,
     health path), and the statement that each keeps its own database;
   - `## Identity`: the Firebase ID token as the bearer token, what `numer_identity` checks (a
     short list and a link to its README), how a backend pins it, the staging project giving a
     different issuer;
   - `## Roles`: the claim, the allowed values, the script and the callable, when a change takes
     effect;
   - `## Account events`: keep the section from P2-07 and link the library function;
   - `## Operations`: the restore test, the monitor, the host scripts, each with one sentence
     and a link to its README or the runbook.
2. `AGENTS.md`: add `backend/numer_identity/` and `infra/` to the repository layout with one line each, and two rules: a module backend never holds a Firebase service account; no file contains a server address.
3. `README.md`: add both directories to the short tree and `infra/RUNBOOK.md` to the docs list.
4. Run `./scripts/verify.sh`.

## Non-goals
- Do not copy the module repos' documentation into this repo.
- Do not describe the client side of modules (later phases).
- Do not change code.

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

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] `grep -rnE "([0-9]{1,3}\.){3}[0-9]{1,3}" docs AGENTS.md README.md infra backend` prints nothing.
- [ ] Each of the five sections exists in `docs/INFRASTRUCTURE.md`.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p2-12-docs-after-identity`, one commit, message `docs: describe backends, identity, roles and operations` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A fact needed here is known only from the server (leave it out and say so).
