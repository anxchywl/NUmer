# P0-16: Docs after foundation

**Recommended model:** sonnet   **Effort:** low
**Risk:** low   **Est.:** 2 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-07, P0-08, P0-15

## Goal
The foundation phase changed facts that `AGENTS.md`, `README.md` and
`docs/INFRASTRUCTURE.md` state. Make each stale claim true or remove it, and give each
subject one owner, so later executors are not misled.

## Read first
- `AGENTS.md`, `README.md`, `docs/INFRASTRUCTURE.md`, `docs/PRODUCT.md`
- `docs/numer2/RESEARCH.md` sections 11.1 and 11.2 (the list of stale claims and duplicates)
- `functions/src/index.ts`, `firestore/firestore.rules`, `scripts/verify.sh`, `test/boundaries/allowlist.txt`

## Context
- Each doc owns its subject once: `AGENTS.md` owns rules for contributors, the repository
  layout and the known debt; `docs/INFRASTRUCTURE.md` owns commands, environments, the data
  model, functions and operations; `docs/PRODUCT.md` owns what the app does; `README.md`
  owns the introduction and links.
- Check every claim against the code as it is on `main` now, not against the research file:
  earlier tasks have already fixed some of it.

## Steps
1. For each row of `RESEARCH.md` 11.1, open the cited doc line and the cited code, and either correct the sentence, or delete it if it no longer applies. Record each row's outcome in the report.
2. `AGENTS.md`:
   - add `## Sources of truth`: a four-row table of which doc owns what;
   - state the dependency rule as enforced by `test/boundaries/`, and add `## Known debt` with
     the current number of allow-listed violations (count the lines of `allowlist.txt`), the
     files above 1000 lines, and the frozen status of `lib/app/app_state.dart`;
   - replace the Firestore rules paragraph with: the rules file is the source; which
     collections are server-only; add a rule and a rules test when adding a collection;
   - add the Hive typeId table (10 to 17 with class names) and the rule that the next free id
     is 18;
   - describe the functions layout by folder in six lines.
3. `docs/INFRASTRUCTURE.md`: correct the functions table to the current exports; state the real
   App Check status (activated on the client in release builds, not enforced on the server);
   remove the "Known follow-ups" section (it moved to `AGENTS.md`); remove the pointer to a
   sessions README that does not exist; fix the Android minimum SDK sentence; add
   `groupIndex`, `publicProfiles`, `config` and `users/{uid}/aggState` to the data
   model; keep the `Environments` section from P0-15.
4. `README.md`: replace the duplicated build and test commands with one line pointing to `./scripts/verify.sh` and `docs/INFRASTRUCTURE.md`; update the docs list.
5. Run `./scripts/verify.sh`.

## Non-goals
- Do not describe NUmer 2.0 features that do not exist yet (modules, the new shell, code-based auth).
- Do not change any code.
- Do not restructure `docs/PRODUCT.md`; correct only sentences that are false.

## Constraints
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] `grep -n "Core never imports a feature" AGENTS.md` prints nothing.
- [ ] `grep -n "README.md" docs/INFRASTRUCTURE.md | grep sessions` prints nothing.
- [ ] The report has one line per row of `RESEARCH.md` 11.1 with: fixed, deleted, or already true.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p0-16-docs-after-foundation`, one commit, message `docs: correct agents, readme and infrastructure after foundation` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A claim cannot be checked from the repository (for example a console setting): mark it in the doc as "set in the console, not in the repo" only if the owner confirms.
