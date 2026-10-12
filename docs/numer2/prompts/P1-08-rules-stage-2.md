# P1-08: Firestore rules stage 2

**Recommended model:** opus   **Effort:** medium
**Risk:** high   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-04, P0-11, P1-06, P1-07, and the owner's confirmation that at least 90% of weekly active users run 1.2.0 or later

## Goal
Close what stage 1 had to leave open for the sake of installed versions: other users'
`users/{uid}` documents are still readable by any signed-in user, unverified accounts can
write, and `email_index` still accepts writes. This stage degrades app versions older than
1.2.0, so it is prepared now and deployed only when the owner says adoption is high enough.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-14
- `firestore/firestore.rules` (all of it)
- `functions/test/rules/stage1.test.ts`
- `functions/scripts/` (existing script style)
- `functions/src/nudges/send_nudge.ts` (how the receiver's language is chosen)

## Context
- App versions from 1.2.0 on: read peers from `publicProfiles`, never read or write
  `email_index`, refresh the ID token right after verifying an email, delete accounts
  through the callable only, and write `users/{uid}.appBuild` with their build number.
- Older versions after this stage: leaderboards lose live names and avatars of other members
  (they fall back to the aggregate copy); a sign-up on an old version reports a false error;
  a freshly verified account on an old version cannot write for up to an hour.
- `request.auth.token.email_verified` is the verified flag in rules.
- Group deletion is done by `deleteGroupCallable` in every version from 1.2.0 on.
- Most blocks in the rules file use the combined form `allow read, write: if X;`, where
  `write` covers create, update and delete.
- `appBuild` on the user document is a number (the build number). A missing or non-number
  value counts as older than any build.
- `sendNudge` picks the push language from the receiver's user document: the first
  non-empty of `language`, `locale`, `languageCode`, lower-cased; a value starting with `ru`
  is Russian; one starting with `kk`, `kz` or `kaz` is Kazakh; anything else is English. A
  token is `doc.data().token ?? doc.id` of each `users/{uid}/fcmTokens` document.
- The switch `DELETE_REQUIRES_RECENT_AUTH` was added by P1-07.

## Steps
1. Add the helper `function isVerified() { return isSignedIn() && request.auth.token.email_verified == true; }`.
2. Change these blocks:
   - `users/{userId}`: `allow get: if isOwner(userId); allow list: if false;
     allow create, update: if isOwner(userId) && isVerified(); allow delete: if false;`
   - `email_index/{emailId}`: `allow read, write: if false;`
   - inside `groups/{groupId}`: `allow delete: if false;` and remove the catch-all
     `match /{document=**}` delete block;
   - writes need a verified email, deletes and reads do not change. For every block under
     `users/{userId}/...` (including `groupMemberships`, `fcmTokens`, habits and their
     `history`) and for `groups/{groupId}` and its `members`, `secrets`, `invites`: split a
     combined rule `allow read, write: if X;` into `allow read: if X;`,
     `allow create, update: if X && isVerified();` and `allow delete: if X;`; split
     `allow write: if X;` the same way; add `&& isVerified()` to existing `allow create` and
     `allow update` lines.
   Leave every read other than `users/{userId}` unchanged. Leave `/nudges`, `publicProfiles`,
   `groupIndex`, `config`, `feed`, `aggregates` and the server-only blocks as they are.
3. `functions/test/rules/stage2.test.ts`:
   Denied: a signed-in user gets another user's `users/{uid}`; an unverified token creates or
   updates `users/self`, a session, a habit, a group, a member document; any client reads or
   writes `email_index`; a creator deletes `groups/G` or a document under it directly.
   Allowed: a verified owner gets and updates `users/self` including `activeSession` and
   `groupIds`; a verified user creates a group, joins and leaves one, writes a session; a
   verified co-member reads `publicProfiles/other`, the other's sessions and aggregates; an
   owner deletes their own session document.
   Update `stage1.test.ts`: create every signed-in test context through one helper that passes
   `{email_verified: true}`. Two stage 1 cases are reversed by stage 2 and move to the denied
   list of `stage2.test.ts`: "a signed-in user gets `users/other`" and "sign-up write to
   `email_index` by an unverified user". Every other stage 1 test still passes.
4. `functions/scripts/delete_email_index.js`: deletes every document of `email_index` in
   batches of 400. `--dry-run` prints the count and deletes nothing. Delete
   `functions/scripts/backfill_email_index.js` and the `backfill:email` npm script.
5. `functions/scripts/send_update_reminder.js --min-build <n> [--dry-run]`: pages through
   `users`; for each user whose `appBuild` is missing, not a number, or below `--min-build`,
   reads `users/{uid}/fcmTokens` and sends one notification per user with FCM
   (`sendEachForMulticast`, at most 500 tokens per call). The language and the token value
   follow the rules in Context, written out in the script. Text:
   - EN: title `Update NUmer`, body `Install the latest version to keep groups and sync working.`
   - RU: title `Обновите NUmer`, body `Установите последнюю версию, чтобы группы и синхронизация продолжали работать.`
   - KK: title `NUmer қолданбасын жаңартыңыз`, body `Топтар мен синхрондау жұмыс істеуі үшін соңғы нұсқаны орнатыңыз.`
   `--dry-run` prints how many users and tokens would be addressed and sends nothing.
6. Add `functions/test/emulator/stage2_scripts.test.ts`: seed three `email_index` documents and three users (builds 10, 50, and none) with one token each; run each script's exported main function with dry-run on and assert the printed counts (3 documents; 2 users and 2 tokens for a minimum build of 40) and that nothing was deleted or sent. Structure each script as an exported `main(args)` plus a two-line entry point so it can be tested.
7. Run `npm run build`, `npm run test:emulator`, `./scripts/verify.sh`.
8. Add to the report a section "Deploy notes": the adoption check, the reminder, the deploy command, the deletion script, the switch to flip (`DELETE_REQUIRES_RECENT_AUTH=on`), the `minSupportedBuild` update, and the rollback (republish the stage 1 rules).

## Non-goals
- Do not deploy. Do not run either script against any real project.
- Do not restrict which fields the owner may write to `users/{uid}`.
- Do not make sessions or courses owner-only (P5-04).
- Do not change `publicProfiles`, `groupIndex`, `config`, `feed` or the server-only blocks.

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
- A rule may use at most 10 document lookups per request; `isVerified()` adds none.

## Acceptance criteria
- [ ] `cd functions && npm run test:emulator` exits 0 with `stage2.test.ts` present.
- [ ] `grep -n "email_index" -A2 firestore/firestore.rules` shows only the closed rule.
- [ ] `grep -n "document=\*\*" firestore/firestore.rules` prints exactly one line, the `users/{userId}/aggregates/{document=**}` block.
- [ ] `ls functions/scripts | grep backfill_email_index` prints nothing.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Check adoption, send the reminder if needed, deploy the rules, delete `email_index`, flip the two switches, raise `minSupportedBuild` (`docs/numer2/USER_ACTIONS.md` C-7).

## Deliverable
Branch `numer2/p1-08-rules-stage-2`, one commit, message `fix: tighten firestore rules stage 2` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A 1.2.0 code path writes under `users/{uid}` before the email is verified (trace `AuthController` from sign-up to the first write).
- A 1.2.0 code path still reads another user's `users/{uid}` (`grep -rn "collection('users')" lib`).
- The current client deletes a group document or a document under a group directly (`grep -rn "\.delete()" lib/features/groups lib/features/auth`); versions older than 1.2.0 do not count.
