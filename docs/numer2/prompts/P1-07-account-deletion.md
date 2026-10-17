# P1-07: Account deletion rework

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 8 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-05, P0-07, P1-02

## Goal
Deleting an account must remove everything about the user and stay removed. Today the
callable leaves `email_index` and nudges behind, triggers re-create documents during the
delete, and a client-side fallback deletes only part of the data. Make deletion complete,
restartable and server-side, and queue an event so module backends can delete their part.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-08 and D-17
- `docs/numer2/RESEARCH.md` section 3.4
- `functions/src/account/delete_account.ts`, `functions/src/groups/cleanup.ts`, `functions/src/groups/triggers.ts`, `functions/src/groups/membership_index.ts`
- `functions/src/aggregates/` (all files)
- `functions/src/profiles/public_profile.ts`
- `functions/src/auth/codes.ts` (`sha256Hex`, `normalizeEmail`)
- `lib/features/auth/data/auth_service.dart` lines 515-720 (the delete flow, the local fallback and its helpers, `_messageForAuthCode`)
- `lib/features/account/screens/account.dart` lines 35-160 and 810-1040 (the confirmation flow)

## Context
- `deleteAccountCallable` today: removes memberships, cascades owned groups, deletes an
  explicit list of subcollections, runs `recursiveDelete(users/{uid})`, deletes the auth
  user. If a step throws, the client runs `_deleteAccountLocally`, which deletes a shorter
  list and then calls `user.delete()`.
- Deleting sessions fires `onStudySessionWrite` once per session. Triggers that write with
  `set(..., {merge: true})` can re-create `users/{uid}`, its `aggregates/statistics`, or
  `groupIndex/{uid}` after they were deleted. In a `WriteBatch`, one `update` of a missing
  document fails the whole batch.
- Not deleted today: `email_index/{email}`, `nudges` where the user is sender or receiver,
  `authCodes`, `publicProfiles/{uid}`, `groupIndex/{uid}`.
- A disabled user cannot call a function again, so the work after disabling must finish on
  the server by itself and be restartable.
- Revoking refresh tokens does not cancel an ID token that is already issued; another
  signed-in device can keep writing for up to an hour. A later sweep handles that.
- Module backends learn about the deletion from a document in `accountEvents`; P2-07
  delivers it. This task only writes it.
- Older app versions call the same callable with no arguments and expect `{success: true}`.
- Client today: `deleteAccount` returns `Future<String?>` (an error message or null), stops
  the sync service before the remote call, and maps Firebase error codes to English
  literals in `_messageForAuthCode`. A wrong password during re-authentication arrives as
  `wrong-password`, `invalid-credential` or `invalid-login-credentials`.
- Kept by design after a deletion, each with an expiry: `deletedUsers/{uid}` (30 days),
  `authAudit` rows (90 days), the `accountEvents` document.
- Triggers and callables are tested in the test process with `firebase-functions-test`
  (`test.wrap`); the functions emulator is not started.

## Steps
1. Triggers must never re-create a user's documents. In every trigger and helper that writes
   under `users/{uid}`, `groupIndex/{uid}` or `publicProfiles/{uid}`:
   - replace `set(ref, data, {merge: true})` on `users/{uid}` and `groupIndex/{uid}` with
     `update`, issued as its own write (not inside a batch shared with other users' documents),
     and treat a `NOT_FOUND` error (gRPC code 5) as "user is gone": return quietly. Where a
     batch updates many users' documents (group deletion), read those documents first and
     update only the ones that exist;
   - in the aggregates code (legacy and incremental), return before any write when the
     `users/{uid}` document read by that code does not exist;
   - `onGroupMemberDelete`: perform its three operations separately so a missing user document
     does not abort the other two.
   List each changed call in the report.
2. Rewrite `deleteAccountCallable` to do only this, in order:
   1. require auth; take the uid and the email (which may be absent) from `context.auth`;
   2. when `process.env.DELETE_REQUIRES_RECENT_AUTH === 'on'`, require
      `Date.now() / 1000 - context.auth.token.auth_time < 300`, else throw
      `HttpsError('failed-precondition', 'Sign in again to delete your account.', {reason: 'recent-login-required'})`;
   3. `admin.auth().updateUser(uid, {disabled: true})` and
      `admin.auth().revokeRefreshTokens(uid)`;
   4. create `deletedUsers/{uid}` with `{uid, emailHash: <sha256Hex of the normalized email, or
      null>, requestedAt, status: 'pending', expiresAt: <Timestamp, now + 30 days>}`. If it
      already exists and its `status` is not `done`, update it with
      `{retryRequestedAt: serverTimestamp}` so the purge runs again;
   5. return `{success: true}`.
3. Add `functions/src/account/purge_user.ts` with an exported `purgeUser(uid)` and the trigger
   `onUserDeletionRequested = functions.runWith({failurePolicy: true, timeoutSeconds: 540,
   memory: '512MB'}).firestore.document('deletedUsers/{uid}').onWrite(...)`, which calls
   `purgeUser` when the document exists with `status === 'pending'` and either it was just
   created or `retryRequestedAt` changed. Every step is idempotent, so a retry is safe:
   1. `removeUserMemberships(uid)` and `deleteGroupCascade` for groups the user created (the
      existing helpers);
   2. delete `users/{uid}` (the root document only) so triggers see it missing;
   3. `db.recursiveDelete(users/{uid})`;
   4. delete `nudges` where `senderId == uid` and where `receiverId == uid`, in batches of 300;
   5. delete every `email_index` document where `uid == uid`. Look up the email with
      `admin.auth().getUser(uid)`; if the user no longer exists (`auth/user-not-found`), skip
      the rest of this step; otherwise delete `authCodes/reset_{sha256Hex(normalized email)}`.
      Always delete `authCodes/verify_{uid}`;
   6. delete `publicProfiles/{uid}` and `groupIndex/{uid}`;
   7. `db.recursiveDelete(users/{uid})` a second time (catches documents written by triggers
      that were already running);
   8. `admin.auth().deleteUser(uid)`, treating "user not found" as success;
   9. create `accountEvents/deleted_{uid}` with `{type: 'account.deleted', issuer:
      'https://securetoken.google.com/' + process.env.GCLOUD_PROJECT, subject: uid,
      occurredAt, status: 'pending'}` using `create`; an already-exists error means it was
      done on an earlier run;
   10. update `deletedUsers/{uid}` with `{status: 'done', completedAt}`.
   A thrown error is logged with `functions.logger.error('user_purge_failed', {uid, step})`
   and rethrown so the platform retries.
4. Late writes. Add `sweepDeletedUsers = functions.pubsub.schedule('every 24 hours')` in the
   same folder: for each `deletedUsers` document with `status == 'done'`, no `sweptAt`, and
   `completedAt` more than 2 hours ago (limit 100), run `db.recursiveDelete(users/{uid})`,
   delete `publicProfiles/{uid}` and `groupIndex/{uid}`, and set `sweptAt`. This removes
   anything another signed-in device wrote before its ID token expired.
   Export the two new functions and add them to the exports test.
5. Client, `lib/features/auth/data/auth_service.dart`:
   - `deleteAccount` takes the user's password and keeps returning `Future<String?>`;
   - first, before the sync service is stopped or any state is cleared, call
     `user.reauthenticateWithCredential(EmailAuthProvider.credential(email: ..., password: ...))`
     and then `user.getIdToken(true)`. On failure return the mapped message and change nothing;
   - then run the existing preparation and the callable. If the callable fails, restart the
     sync service the way the existing failure path does and return the generic message;
   - on success sign out locally and clear local data exactly as the existing success path
     does;
   - delete `_deleteAccountLocally` and the helpers only it used (`_deleteUserOwnedData`,
     `_deleteUserProfileDocument`, `_removeUserMemberships`, `_deleteGroupsOwnedBy`,
     `_deleteOwnedGroupCascade`, `_deleteDocumentRefs`, `_deleteQueryBatch`), confirming with
     `grep` that each has no other caller;
   - messages come from ARB keys, passed in by the caller or resolved in the screen: map
     `wrong-password`, `invalid-credential` and `invalid-login-credentials` to
     `deleteAccountWrongPassword`, `network-request-failed` to `deleteAccountNetworkError`,
     anything else to `deleteAccountFailed`. Return a small enum from the controller and map it
     to text in the screen if the controller has no access to localizations.
6. Client, `lib/features/account/screens/account.dart`: after the existing hold-to-confirm and
   typed-text confirmation, ask for the password in a bottom sheet per `DESIGN.md` 5.7: title
   `deleteAccountPasswordTitle` in `titleMedium` bold, one obscured filled text field (radius
   12), the error line under the field in `bodySmall` with `colorScheme.error`, a full-width
   `FilledButton` 48 high in `colorScheme.error` with the existing delete label (it shows its
   loading state while the request runs), and a `TextButton` with the existing cancel label.
   Padding 16; top corners 20. On failure show the mapped message in the sheet and keep the
   user signed in. Strings:
   - `deleteAccountPasswordTitle`: EN `Enter your password to delete the account` / RU `Введите пароль, чтобы удалить аккаунт` / KK `Аккаунтты жою үшін құпиясөзді енгізіңіз`
   - `deleteAccountWrongPassword`: EN `Wrong password. Try again.` / RU `Неверный пароль. Попробуйте ещё раз.` / KK `Құпиясөз қате. Қайталап көріңіз.`
   - `deleteAccountNetworkError`: EN `No connection. Try again.` / RU `Нет соединения. Попробуйте ещё раз.` / KK `Байланыс жоқ. Қайталап көріңіз.`
   - `deleteAccountFailed`: EN `Could not delete the account. Try again.` / RU `Не удалось удалить аккаунт. Попробуйте ещё раз.` / KK `Аккаунтты жою мүмкін болмады. Қайталап көріңіз.`
7. Tests:
   - `functions/test/emulator/delete_account.test.ts`: seed a user with a document in every
     subcollection named in `RESEARCH.md` 3.4, membership in two groups (one owned), sent and
     received nudges, `email_index`, `authCodes`, `publicProfiles`, `groupIndex`. Call the
     wrapped callable, then `purgeUser(uid)`, then run the wrapped `onStudySessionWrite` once
     for a deleted session and the wrapped `onGroupMemberWrite` once for a deleted member (the
     late-trigger case). Assert: no document exists under `users/{uid}`, nor the user's
     `email_index`, `authCodes`, `publicProfiles`, `groupIndex`, nudges, group member or
     aggregate documents; the Auth user is gone; `accountEvents/deleted_{uid}` exists;
     `deletedUsers/{uid}.status` is `done`.
   - `purgeUser` run twice leaves the same end state and one event; run after the Auth user is
     already deleted it still finishes.
   - a second callable call while `status` is `pending` sets `retryRequestedAt`.
   - the sweep deletes a `users/{uid}/sessions` document written after the purge.
   - with `DELETE_REQUIRES_RECENT_AUTH=on`, an `auth_time` 10 minutes old is rejected.
   - a group deletion where one member's user document is missing still updates the others.
   - `test/features/account/delete_account_sheet_test.dart`: a wrong password shows
     `deleteAccountWrongPassword` and does not call the callable; success signs out. Use a
     hand-written fake of the controller method.
8. Add `DELETE_REQUIRES_RECENT_AUTH=off` to `functions/.env.example`. Run `npm run build`, `npm test`, `npm run test:emulator`, `flutter gen-l10n`, `./scripts/verify.sh`. In the report, note that after the callable returns, the same email cannot sign up again until the purge has finished.

## Non-goals
- Do not deliver account events to modules (P2-07).
- Do not change `firestore/firestore.rules`.
- Do not turn `DELETE_REQUIRES_RECENT_AUTH` on by default: older app versions cannot re-authenticate.
- Do not delete `nudgeLimits`, `joinAttempts` or `authRateLimits` documents by hand; they hold no personal content and expire by TTL within 3 days.
- Do not add a per-event read of `deletedUsers` to the aggregate triggers (it would add a read to every study session).
- Do not remove the hold-to-confirm or the typed confirmation.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Cloud Functions keep the v1 API style (`firebase-functions/v1`) and the default region already in use. Do not change a deployed function's name, trigger path or region.
- Client-supplied ids, emails and text are validated before use. Errors returned to clients are generic; details go to `functions.logger`.
- Server-only collections are written with the Admin SDK only and are denied to clients in `firestore/firestore.rules`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- Every purge step is safe to run twice.
- Nothing on the purge path, and no trigger, uses `set(..., {merge: true})` on `users/{uid}` or `groupIndex/{uid}`.

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test && npm run test:emulator` exits 0 with the emulator tests of step 7 present.
- [ ] `grep -rn "_deleteAccountLocally\|_deleteUserOwnedData\|_deleteOwnedGroupCascade" lib` prints nothing.
- [ ] `grep -rn -B4 "merge: true" functions/src` shows no write to `users/{uid}` or `groupIndex/{uid}`; the report lists each remaining `merge: true` with its target.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The report lists every trigger write changed in step 1.
- [ ] Screenshots attached to the report: each new or changed screen in light and dark mode, in EN and RU (add KK where labels are long), plus one at text scale 1.3. For screens that load data: loading, empty and error states. If you cannot run the app on a device or simulator, produce the images from a widget test that pumps the screen and writes them with `matchesGoldenFile` (run with `--update-goldens`), attach them, and do not commit them. Never fabricate an image; if none can be produced, say so.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- On staging: create an account with data, delete it, search the database for the uid (`docs/numer2/USER_ACTIONS.md` C-6).
- Add a TTL policy on `deletedUsers.expiresAt`.

## Deliverable
Branch `numer2/p1-07-account-deletion`, one commit, message `fix: make account deletion complete and restartable` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, screenshots, anything you could not verify, and user actions still pending.

## Stop and ask if
- A trigger legitimately needs to create `users/{uid}` (for example for a user who never opened the app).
- `failurePolicy` or `pubsub.schedule` is not accepted by the installed v1 API.
- The explicit subcollection list in the old callable deletes something `recursiveDelete` does not reach.
- The existing delete flow clears local state in a way that cannot be moved after re-authentication.
