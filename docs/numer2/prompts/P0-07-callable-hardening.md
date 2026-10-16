# P0-07: Callable hardening

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-04

## Goal
Make the existing callables safe to leave public: validate every id, enforce the nudge
cooldown on the server, limit join-code guessing, remove two dead functions, and stop
returning internal error text.

## Read first
- `AGENTS.md`
- `functions/src/groups/callables.ts`, `functions/src/groups/cleanup.ts`, `functions/src/groups/triggers.ts`
- `functions/src/nudges/send_nudge.ts`
- `functions/src/shared/`
- `lib/features/groups/data/group_service.dart` lines 851-925 and 986-1002 (how the client calls and reads errors)

## Context
- Callable ids are used unvalidated: `db.collection('groups').doc(groupId)` accepts a path
  with slashes, so `"G/members/ATT"` resolves to a document the attacker controls.
- `sendNudge` has no server limit. The client keeps its own one-hour cooldown per pair in a
  document it writes itself. The push body includes the sender's `profileName` unbounded.
- `joinPrivateGroup` compares the stored `joinCode` (plain text in
  `groups/{g}/secrets/settings`) with `!==` and has no attempt limit. Installed versions read
  and write that plain code, so its storage format must not change.
- `getMemberSubjectStats` has no caller in the app and leaks study data through any public
  group. `deleteGroup` is a trigger with an empty body.
- `deleteGroupCascade` and `deleteGroupCallable` put two writes per member into one batch;
  above 250 members the batch exceeds the 500-write limit.
- Installed clients show `error.message` of a `FirebaseFunctionsException` to the user, so
  messages must stay human-readable English sentences.

## Steps
1. Create `functions/src/shared/validation.ts`:
   - `assertId(value: unknown, name: string): string` throws
     `HttpsError('invalid-argument', '<name> is invalid.')` unless `typeof value === 'string'`
     and it matches `/^[A-Za-z0-9_-]{1,128}$/`; returns the value.
   - `assertString(value: unknown, name: string, maxLength: number): string` likewise for a
     non-empty string up to `maxLength`.
   Use `assertId` for every `groupId`, `userId`, `targetUserId` argument of every callable and
   `assertString(joinCode, 'joinCode', 64)` in `joinPrivateGroup`, before any Firestore call.
   `assertString` throws `HttpsError('invalid-argument', '<name> is invalid.')`. Keep the
   existing alphanumeric check of the join code after it.
2. Delete `getMemberSubjectStats` and `deleteGroup` with all code only they use. Remove them from `functions/src/index.ts` and from the expected list in `functions/test/unit/exports.test.ts`.
3. `sendNudge`: after every existing validation has passed (membership, the target profile,
   `allowNudges`, the token check) and immediately before the `nudges` document is added, run
   one transaction:
   - `nudgeLimits/{senderId}_{targetUserId}`: if `lastAt` is less than 3600 seconds ago, throw
     `HttpsError('resource-exhausted', 'You already nudged this person. Try again later.')`;
   - `nudgeLimits/day_{senderId}_{YYYYMMDD UTC}`: if `count >= 30`, throw
     `HttpsError('resource-exhausted', 'Daily nudge limit reached.')`;
   - otherwise set `lastAt` to now, increment `count`, and set `expiresAt` (a Firestore
     `Timestamp`) to now plus 2 days on both.
4. `sendNudge`: build the sender name with a new pure function
   `sanitizeDisplayName(raw: unknown): string` in `functions/src/nudges/sanitize.ts`: non-string
   becomes `''`; remove every match of `/https?:\/\/\S+|www\.\S+/gi`; collapse whitespace;
   trim; cut to 40 characters. If the result is empty use the existing fallback name.
5. `joinPrivateGroup`: before reading the secret, run a transaction on
   `joinAttempts/{uid}_{groupId}` (`count`, `windowStart`) and
   `joinAttempts/group_{groupId}_{YYYYMMDD UTC}` (`count`):
   - the user's window starts at `windowStart`, set on the first wrong attempt and again when
     3600 seconds have passed (which also resets `count` to 0); the group counter has no
     window, its document id carries the UTC date;
   - if the user's `count >= 5` or the group's `count >= 50`, throw
     `HttpsError('resource-exhausted', 'Too many attempts. Try again later.')`.
   The existing function does its work inside one transaction and throws inside it; a throw
   rolls a transaction back, so counters must not be written there. Order: (1) a small
   transaction reads the two counters and refuses when a limit is reached; (2) the existing
   join transaction returns a flag for a wrong code instead of throwing; (3) for a wrong code,
   a third transaction increments both counters (with `expiresAt`, a `Timestamp`, = now plus 2
   days) and then the function throws the existing `permission-denied` error. A correct code
   does not increment.
   Compare codes with `crypto.timingSafeEqual` on two UTF-8 buffers after checking that their
   lengths are equal (unequal lengths are a wrong code).
6. In `deleteGroupCascade` and `deleteGroupCallable`, change the member chunk size so each batch holds at most 200 members (two writes each).
7. In `sendNudge` and the group callables, replace every place that returns `error.message`, `String(err)` or an interpolated error to the client with a fixed sentence, and log the original with `functions.logger.error`. The sentences for `not-found`, `permission-denied`, `failed-precondition` and `already-exists` that exist today stay as they are. Leave `analyzeCourseAi` alone (a later task owns it).
8. Tests:
   - `functions/test/unit/validation.test.ts`: `assertId` accepts `abc_DEF-123`; rejects `''`,
     `'a/b'`, `{}`, a 129-character string.
   - `functions/test/unit/sanitize.test.ts`: URL removed; 200 characters cut to 40; non-string
     gives `''`.
   - `functions/test/emulator/nudge_limits.test.ts` (wrap the callable with
     `firebase-functions-test`; replace FCM sending with a stub injected through a module-level
     setter that you add for tests only if no seam exists): second nudge to the same target
     within an hour rejects with `resource-exhausted`; with 31 different targets, each seeded
     as a group member with one `fcmTokens` document, the 31st nudge of a day rejects; a nudge
     that fails validation does not use up the limit.
   - `functions/test/emulator/join_attempts.test.ts`: five wrong codes then a correct one
     rejects with `resource-exhausted`; a correct first attempt joins.
   - `functions/test/emulator/callable_ids.test.ts`: for each callable that takes an id
     (`deleteGroupCallable`, `joinPrivateGroup`, `sendNudge`), the value `'G/members/x'` and
     the value `{}` each reject with `invalid-argument`.
   Callables are invoked in the test process with `firebase-functions-test` (`test.wrap`); the
   functions emulator is not started.
9. Remove the rows of `getMemberSubjectStats` and `deleteGroup` from the Cloud Functions table in `docs/INFRASTRUCTURE.md`.
10. Run `npm run build`, `npm test`, `npm run test:emulator`, `./scripts/verify.sh`. If `functions/src/index.ts` or `functions/test/unit/exports.test.ts` changed on `main` while you worked, rebase and keep both sets of lines.

## Non-goals
- Do not change how join codes are stored or who generates them.
- Do not enable App Check (P1-09).
- Do not change `deleteAccountCallable` (P1-07) or the aggregates (P0-08).
- Do not change the client. The client-written `nudgeCooldowns` documents stay.

## Constraints
- Cloud Functions keep the v1 API style (`firebase-functions/v1`) and the default region already in use. Do not change a deployed function's name, trigger path or region.
- Client-supplied ids, emails and text are validated before use. Errors returned to clients are generic; details go to `functions.logger`.
- Server-only collections are written with the Admin SDK only and are denied to clients in `firestore/firestore.rules`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- Error messages returned to clients are short English sentences, because installed versions display them.

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test && npm run test:emulator` exits 0.
- [ ] `grep -rn "getMemberSubjectStats\|export const deleteGroup " functions/src` prints nothing.
- [ ] `functions/test/emulator/callable_ids.test.ts` passes for the three callables, and the report lists, for each callable, the line where each id argument passes through `assertId`.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Deploy functions; confirm the deletion of `getMemberSubjectStats` and `deleteGroup` when the CLI asks; add TTL policies on `nudgeLimits.expiresAt` and `joinAttempts.expiresAt` (`docs/numer2/USER_ACTIONS.md` B-5).

## Deliverable
Branch `numer2/p0-07-callable-hardening`, one commit, message `fix: harden group and nudge callables` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- `getMemberSubjectStats` turns out to be called from `lib/` (`grep -rn getMemberSubjectStats lib`).
- FCM sending cannot be stubbed without restructuring `sendNudge`.
- A collection named `nudgeLimits` or `joinAttempts` already exists in code.
