# P1-09: App Check switchable per callable

**Recommended model:** sonnet   **Effort:** medium
**Risk:** med   **Est.:** 3 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-04

## Goal
`requireAppCheck` is a no-op, so App Check protects no callable. Replace it with a check that
can be switched on per callable by configuration, so the owner can enforce it one callable at
a time without a code change.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-06
- `functions/src/shared/app_check.ts` and every call of `requireAppCheck`

## Context
- `requireAppCheck(context)` returns on its first line; the real check is commented out. In
  the v1 API a verified App Check token appears as `context.app`.
- The three password-reset callables use their own switch (`AUTH_ENFORCE_APPCHECK`); they
  are not part of this task.
- Handlers are tested in the test process; the functions emulator is not started.

## Steps
1. `functions/src/shared/app_check.ts`: replace the no-op with
   - `parseEnforced(value: string | undefined): Set<string>` (comma-separated names, trimmed;
     `*` means all);
   - `requireAppCheck(context, name: string, enforced: Set<string> = <parsed once from
     process.env.APPCHECK_ENFORCED>)`: when `enforced` has `name` or `*` and
     `context.app === undefined`, throw
     `HttpsError('failed-precondition', 'This request could not be verified.', {reason: 'app-check'})`.
   Pass the export name at every existing call site. Delete the commented-out block.
2. Add `APPCHECK_ENFORCED=` (empty) to `functions/.env.example` (create it if missing; if
   `git check-ignore functions/.env.example` reports it ignored, add `!functions/.env.example`
   to `.gitignore` after the rule that ignores it), and three sentences to
   `docs/INFRASTRUCTURE.md` on how enforcement is switched on per callable.
3. `functions/test/unit/app_check.test.ts`: `parseEnforced` cases; an empty set never throws;
   a listed name throws without `context.app` and passes with it; `*` covers every name.
4. Run `npm run build`, `npm test`, `./scripts/verify.sh`.

## Non-goals
- Do not enforce App Check by default; the list stays empty in the repo.
- Do not use `runWith({enforceAppCheck})` on existing callables; enforcement must be changeable without a code change.
- Do not change any callable's behaviour other than the App Check call.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- Cloud Functions keep the v1 API style (`firebase-functions/v1`) and the default region already in use. Do not change a deployed function's name, trigger path or region.
- Client-supplied ids, emails and text are validated before use. Errors returned to clients are generic; details go to `functions.logger`.
- Server-only collections are written with the Admin SDK only and are denied to clients in `firestore/firestore.rules`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test` exits 0.
- [ ] `grep -rn "requireAppCheck(context)" functions/src` prints nothing (every call passes a name).
- [ ] `git check-ignore functions/.env.example` prints nothing.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Check App Check metrics, then add callables to `APPCHECK_ENFORCED` one at a time (`docs/numer2/USER_ACTIONS.md` C-8).

## Deliverable
Branch `numer2/p1-09-app-check`, one commit, message `feat: make app check switchable per callable` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A callable reads `context.app` for another purpose.
- `firebase-functions` `^7` v1 API does not expose `context.app`.
