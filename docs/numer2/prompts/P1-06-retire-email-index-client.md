# P1-06: Retire `email_index` on the client

**Recommended model:** sonnet   **Effort:** medium
**Risk:** low   **Est.:** 3 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P1-05

## Goal
With code-based auth the client has no reason to read or write the public `email_index`
collection or to mirror `emailVerified` into the profile. Remove that code and the last
hard-coded English strings in the auth feature, so stage 2 rules can close the collection.

## Read first
- `AGENTS.md`
- `docs/DESIGN.md` section 8
- `lib/features/auth/data/auth_service.dart` (all of it)
- `lib/features/auth/screens/` (all files)
- `lib/l10n/app_en.arb`

## Context
- `_upsertEmailIndex` is called at two places: unawaited in `_handleAuthState` and awaited in
  `register`. Nothing reads `email_index` any more after P1-05.
- `_ensureProfileDocument` writes `emailVerified` into `users/{uid}` on create and on drift.
  Nothing reads that field after P1-05. The `email` field in the same document stays.
- `auth_service.dart` and the auth screens still return or show English literals such as
  `'Failed to send verification email. Please try again.'`. The controller should return
  typed reasons and the UI should map them to ARB strings.
- Older app versions keep writing `email_index`; that is handled by the rules, not here.
- A class named `AuthFailure` already exists in `auth_service.dart` and carries only a message. Replace it with the new enum where it is used, or keep it and add the enum beside it; do not create a second type with the same name.

## Steps
1. Delete `_upsertEmailIndex`, both call sites, and the `SharedPreferences` gate added for it in P0-10.
2. In `_ensureProfileDocument` remove `emailVerified` from the created document and from the drift update. Keep every other field.
3. Replace every user-visible string literal in `lib/features/auth/` with an ARB string. Where
   the controller returns a `String?` error today, return a value of a new
   `enum AuthErrorKind { ... }` (one value per distinct message) and map it in the screen. Reuse
   existing ARB keys where the meaning matches; add new keys in EN, RU and KK otherwise,
   following the copy rules (no exclamation marks, a sentence that says what failed and what to
   do).
4. In the register form, an address that is already registered shows a new string `emailInUseHint` (EN `This email already has an account. Sign in or reset the password.`, RU `Аккаунт с этой почтой уже есть. Войдите или сбросьте пароль.`, KK `Бұл поштамен аккаунт бар. Кіріңіз немесе құпиясөзді қалпына келтіріңіз.`), mapped from the `AuthErrorKind` value for the Firebase code `email-already-in-use`.
5. Remove dead code in the auth feature: any method with no caller (confirm each with `grep -rn`).
6. Add or extend `test/features/auth/auth_error_kind_mapping_test.dart`: every `AuthErrorKind` value maps to a non-empty string in each of the three locales.
7. Run `flutter gen-l10n` and `./scripts/verify.sh`.

## Non-goals
- Do not touch `firestore/firestore.rules` or any function (P1-08 does).
- Do not delete `functions/scripts/backfill_email_index.js` (P1-08 does).
- Do not change sign-in, sign-up or reset behaviour; only how failures are represented.
- Do not remove the `email` field from the profile document.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `grep -rn "email_index" lib/` prints nothing.
- [ ] `grep -rn "emailVerified'" lib/features/auth/data/auth_service.dart` prints nothing.
- [ ] `grep -rnE "return '[A-Z][a-z]+ " lib/features/auth` prints nothing.
- [ ] `./scripts/verify.sh` exits 0, including the ARB parity check.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p1-06-retire-email-index-client`, one commit, message `refactor: remove email index and literals from auth client` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- Another feature reads `users/{uid}.emailVerified` (`grep -rn emailVerified lib`).
- A caller outside the auth feature depends on the `String?` error return.
