# P0-10: Remove redundant writes

**Recommended model:** sonnet   **Effort:** medium
**Risk:** med   **Est.:** 3 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-02

## Goal
Each cold start writes the FCM token, an FCM flag and an email index entry even when nothing
changed, and each app load re-sends the active-session state. Every write to the user
document also wakes the presence listener of every group peer. Send these writes only when
their content changed.

## Read first
- `AGENTS.md`
- `lib/features/auth/data/auth_service.dart` lines 106-150 (`_handleAuthState`), 255-320 (`_registerPushToken`, `_saveFcmToken`), 340-370 (`_clearLocalUserData`), 855-875
- `lib/app/app_state.dart` lines 490-500 and 2020-2110 (`_saveActiveSession`), and `reset`
- `lib/core/data/sync_service.dart` lines 405-490 (`updateActiveSession`, the heartbeat, `_listenActiveSession`)

## Context
- `_handleAuthState` calls, unawaited, on every verified auth state (lines 144-146):
  `_ensureProfileDocument`, `_upsertEmailIndex`, `_registerPushToken`.
- `_saveFcmToken` (about `:294-318`) writes `users/{uid}/fcmTokens/{token}` and then
  `users/{uid}` `{fcmEnabled: true, fcmTokenUpdatedAt}` every time. It also serves the
  token-refresh listener.
- `_upsertEmailIndex` (`:860-872`) writes `email_index/{email}` every time. It is also
  awaited once during sign-up (`:434`); leave that call as it is.
- `_saveActiveSession` (`app_state.dart:2020-2107`) ends by awaiting
  `sync.updateActiveSession(...)` (`:2099`), which writes `activeSession`, `isStudying` and
  `lastActive` to `users/{uid}`. `_performLoad` calls it on every load (`:495-497`), and a
  load runs after every pull.
- `SyncService.updateActiveSession` returns without writing when its `_uid` or `_deviceId`
  is null (about `:417`), which can happen when a load runs before the service has started.
- The heartbeat (`sync_service.dart:453-468`) writes `activeSession.deviceId` on start. It
  implements single-device sign-in and must stay.
- Local data of a user is cleared in `AuthController._clearLocalUserData(uid)`, which every
  sign-out path reaches (manual, forced, account deletion). `signOut` alone is not enough.
- `AppState` has no uid field; other code in it uses `FirebaseAuth.instance.currentUser`.
- `SharedPreferences` is already used in `lib/` for small device-local values.

## Steps
1. First read `_listenActiveSession` in `sync_service.dart`. Confirm that it compares only `activeSession.deviceId` and does not use `activeSession.updatedAt` or `lastActive` to decide anything. If it does use either as a freshness signal, stop and ask.
2. FCM token: in `_saveFcmToken`, read `SharedPreferences` keys `fcm_saved_token_<uid>` and
   `fcm_saved_at_<uid>`. If `shouldSaveFcmToken` (step 6) is false, return without writing.
   Store the token and the time only after both writes have succeeded.
3. Email index: add a private async method `_upsertEmailIndexIfChanged(User user)`: return when
   the email is null or empty; read `SharedPreferences` key `email_index_written_<uid>`; when
   `shouldUpsertEmailIndex` is true, await `_upsertEmailIndex` and then set the key to the
   normalized email. Call it, unawaited, at line 145 in place of the direct call. The sign-up
   call at line 434 stays as it is.
4. Active session:
   - change `SyncService.updateActiveSession` to return `Future<bool>`: `false` on its early
     return, `true` after its write has been awaited. Change nothing else in it;
   - in `_saveActiveSession`, take the uid from `FirebaseAuth.instance.currentUser?.uid`. If it
     is null, behave exactly as today. Otherwise compute `activeSessionSignature` (step 6) from
     the values about to be sent. If it equals the last signature sent for that uid, skip the
     `updateActiveSession` call. The last signature is kept in a field holding the pair (uid,
     signature) and in `SharedPreferences` key `active_session_sig_<uid>`;
   - store the signature only when `updateActiveSession` returned `true`;
   - clear the in-memory pair in `AppState.reset()`.
5. In `AuthController._clearLocalUserData(uid)` remove the four keys `fcm_saved_token_<uid>`, `fcm_saved_at_<uid>`, `email_index_written_<uid>` and `active_session_sig_<uid>`. Do not change `signOut`.
6. Pure top-level functions, each in the file where it is used:
   - `bool shouldSaveFcmToken(String token, String? savedToken, int? savedAtMs, int nowMs)`:
     true when the saved token is null or different, or it was saved 7 days or more ago;
   - `bool shouldUpsertEmailIndex(String normalizedEmail, String? written)`: true when they
     differ;
   - `String activeSessionSignature({required bool isStudying, String? courseId, String? kind,
     int? startMs, int? expectedEndMs})` returning
     `'$isStudying|${courseId ?? '-'}|${kind ?? '-'}|${startMs ?? '-'}|${expectedEndMs ?? '-'}'`.
   Tests: `test/features/auth/auth_write_gates_test.dart` (same token within 7 days is skipped,
   at 7 days it is saved, a new token is saved, a null saved token is saved; same email is
   skipped, a different one is not) and `test/app/active_session_signature_test.dart`
   (signatures differ when any one value differs and are equal otherwise). Import only the
   functions, for example
   `import 'package:numer_app/app/app_state.dart' show activeSessionSignature;`.
7. Run `./scripts/verify.sh`.

## Non-goals
- Do not change `Storage.deleteSession`: its direct Firestore query can match documents whose id differs from the local one, and removing it could leave duplicates. It is out of scope.
- Do not remove or throttle the heartbeat.
- Do not change `_ensureProfileDocument`, the sign-up flow, or the awaited `_upsertEmailIndex` call during sign-up.
- Do not change which fields `updateActiveSession` writes.
- No new user-facing string is expected.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
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
- [ ] `./scripts/verify.sh` exits 0.
- [ ] Both new test files pass.
- [ ] `grep -rn "shouldSaveFcmToken\|shouldUpsertEmailIndex\|activeSessionSignature" lib` prints each name at least twice (its definition and its use).
- [ ] `grep -n "Future<bool> updateActiveSession" lib/core/data/sync_service.dart` prints one line.
- [ ] `grep -n "active_session_sig_\|fcm_saved_token_\|email_index_written_" lib/features/auth/data/auth_service.dart` shows the removals in `_clearLocalUserData`.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p0-10-redundant-writes`, one commit, message `perf: skip unchanged token, email index and session writes` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- `_listenActiveSession` uses `updatedAt` or `lastActive` (step 1).
- A test file cannot compile because importing `app_state.dart` or `auth_service.dart` pulls a plugin that fails in `flutter test` (do not move the functions; ask).
- `_clearLocalUserData` is not reached by one of the sign-out paths.
