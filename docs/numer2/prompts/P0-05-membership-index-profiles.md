# P0-05: Membership index and public profiles

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-04

## Goal
Create two server-written collections that security rules and clients can trust:
`groupIndex/{uid}` (which groups a user really belongs to) and `publicProfiles/{uid}` (what
group peers may see of a user). The stage 1 rules (P0-06) and the groups client (P0-11)
depend on them. Triggers do the writing, so every installed app version keeps working.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-14 and D-15
- `functions/src/groups/triggers.ts`, `functions/src/groups/callables.ts` (`joinPrivateGroup`)
- `functions/src/shared/admin.ts`
- `functions/scripts/backfill.js` (how scripts initialise the Admin SDK)
- `functions/test/emulator/ai_quota.test.ts` (test style)

## Context
- Membership truth is the document `groups/{groupId}/members/{memberId}`. It is created by
  the client for public groups and by `joinPrivateGroup` for private ones, and deleted on
  leave, removal, group deletion and account deletion.
- Today the rules decide peer access from `users/{uid}.groupIds`, which the owner can write.
  That field stays; it just stops being trusted.
- Fields the client writes to `users/{uid}` that peers read today: `profileName`,
  `displayName`, `major`, `profileGoal`, `profileContact`, `profileAvatarIndex`,
  `avatarIndex`, `avatarColorValue`, `profileAvatarColorValue`, `profileAvatarImageBase64`,
  `avatarImageBase64`, `isStudying`, `activeSession` (a map with `deviceId`, `updatedAt`,
  `courseId`, `kind`, `startUtc`, `expectedEndUtc`), `allowNudges`, `fcmEnabled`.
- `users/{uid}` also holds `email`, `emailVerified`, settings and `activeSession.deviceId`.
  None of those may reach the public profile.
- The user document is written 12 to 18 times a day per user, mostly for `activeSession`.
  The mirror must write only when a mirrored field changed.
- An existing trigger, `onGroupMemberDelete`, already handles deletes of the same path. Leave
  it as it is; two triggers on one path are fine.
- Events can arrive twice or out of order.
- `onUserProfileWrite` will run on every write of a user document; most runs write nothing.
  That is expected.
- The deny rules for `groupIndex` and `publicProfiles` are added by P0-06. Do not add them
  here.
- Emulator tests run through `npm run test:emulator`, which starts the Firestore and Auth
  emulators and sets `FIRESTORE_EMULATOR_HOST`. Triggers are called in the test process with
  `firebase-functions-test` (`test.wrap`, `test.firestore.makeDocumentSnapshot`,
  `test.makeChange`); the functions emulator is not started.

## Steps
1. Create `functions/src/groups/membership_index.ts` exporting
   `onGroupMemberWrite = functions.firestore.document('groups/{groupId}/members/{memberId}').onWrite(...)`:
   - when both `before` and `after` exist (an update), do nothing;
   - otherwise re-read `groups/{groupId}/members/{memberId}` and act on what exists now, not on
     the event: if it exists,
     `groupIndex/{memberId}.set({groupIds: FieldValue.arrayUnion(groupId), updatedAt: serverTimestamp}, {merge: true})`;
     if it does not, the same with `FieldValue.arrayRemove(groupId)`. This makes a late or
     repeated event harmless. An index document left with an empty list stays; account
     deletion removes it in a later task.
2. Create `functions/src/profiles/public_profile.ts` exporting:
   - `toPublicProfile(data: FirebaseFirestore.DocumentData | undefined): PublicProfile | null`,
     a pure function. It returns `null` for `undefined`. Otherwise exactly these keys:
     `profileName` = `data.profileName ?? data.displayName ?? ''` (string);
     `major`, `profileGoal`, `profileContact` = the string value or `null`;
     `avatarIndex` = `data.profileAvatarIndex ?? data.avatarIndex ?? null` (number or null);
     `avatarColorValue` = `data.avatarColorValue ?? data.profileAvatarColorValue ?? null`;
     `avatarImageBase64` = `data.profileAvatarImageBase64 ?? data.avatarImageBase64 ?? null`;
     `isStudying` = `data.isStudying === true`;
     `activeSession` = `null` unless `data.activeSession` is an object, then
     `{courseId, kind, startUtc, expectedEndUtc}` copied from it (missing values as `null`);
     `allowNudges` = `data.allowNudges !== false`;
     `fcmEnabled` = `data.fcmEnabled === true`.
     Types are enforced: `profileName` must be a string, else `''`; `major`, `profileGoal`,
     `profileContact` and `avatarImageBase64` must be strings, else `null`; `avatarIndex` and
     `avatarColorValue` must be numbers (`typeof === 'number'`), else `null`; `activeSession`
     must be a plain map (not an array, not a `Timestamp`). An `avatarImageBase64` longer than
     700000 characters becomes `null`, so the mirror cannot approach the document size limit.
   - `publicProfilesEqual(a, b): boolean`, a pure deep comparison that treats two Firestore
     `Timestamp` values as equal when `isEqual` is true.
   - `onUserProfileWrite = functions.firestore.document('users/{userId}').onWrite(...)`:
     compute the projection of `before` and of `after`; if `after` is missing, delete
     `publicProfiles/{userId}`; else if the projections are equal, return without writing; else
     `publicProfiles/{userId}.set({...projection, updatedAt: serverTimestamp})` (no merge).
3. Export both triggers from `functions/src/index.ts` and add their names to the expected list in `functions/test/unit/exports.test.ts`.
4. Create `functions/scripts/backfill_group_index.js`: read every document of
   `collectionGroup('members')` whose parent path is `groups/{groupId}/members`, build a map
   uid to group ids, and write `groupIndex/{uid}` as `{groupIds, updatedAt}` with `set` (no
   merge) in batches of 400. Skip any `members` document whose grandparent collection is not
   `groups`. It prints one line `users=<n> memberships=<m>`; with `--dry-run` it writes
   nothing. Like `functions/scripts/backfill.js`, it exits with an error unless
   `FORCE_BACKFILL=1` is set, and before doing anything it prints its target (the emulator
   host, or the project id). You run it only against the emulator:
   `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-numer FORCE_BACKFILL=1 node scripts/backfill_group_index.js --dry-run`.
5. Create `functions/scripts/backfill_public_profiles.js`: page through `users` 300 at a time
   (ordered by document id), write `publicProfiles/{uid}` from the same projection logic
   (require the built file `lib/profiles/public_profile.js`; run `npm run build` first),
   batches of 300. It prints `users=<n>`. Same `--dry-run`, `FORCE_BACKFILL` and target-print
   behaviour as the other script. Add npm scripts `backfill:group-index` and
   `backfill:public-profiles`.
6. Tests:
   - `functions/test/unit/public_profile.test.ts`: the projection of a full user document has
     exactly the 11 keys listed; it has no `email`, `emailVerified` or `deviceId` anywhere
     (search the JSON text); `allowNudges` defaults to true; `profileAvatarIndex` wins over
     `avatarIndex`; two projections that differ only in `activeSession.startUtc` are not equal;
     two built from documents that differ only in `email`, `lastActive` and
     `activeSession.deviceId` are equal; a number in `profileName` gives `''`; an array in
     `activeSession` gives `null`; an image of 700001 characters gives `null`.
   - `functions/test/emulator/membership_index.test.ts` (use `firebase-functions-test` to wrap
     the trigger and call it with before and after snapshots against the Firestore emulator):
     create adds the group id; a second group adds a second id; delete removes one; update
     leaves the document unchanged; a create event delivered after the member document was
     already deleted leaves the id out.
   - `functions/test/emulator/public_profile.test.ts`: create writes the mirror; a change of
     `profileName` rewrites it; a change of only `email` leaves `updatedAt` unchanged; delete
     removes it.
7. In `docs/INFRASTRUCTURE.md` add the two triggers to the Cloud Functions table and the two collections to the data model list.
8. Run `npm run build`, `npm test`, `npm run test:emulator`, `./scripts/verify.sh`. If `functions/src/index.ts` or `functions/test/unit/exports.test.ts` changed on `main` while you worked, rebase and keep both sets of lines.

## Non-goals
- Do not edit `firestore/firestore.rules` (P0-06 does).
- Do not change the client. Do not stop any existing write of `users/{uid}.groupIds`.
- Do not change `onGroupMemberDelete`, `joinPrivateGroup` or `updateUserAggregates`.
- Do not mirror any field not listed in step 2.

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
- `toPublicProfile` is the only place that decides which fields are public; the trigger and the backfill both use it.

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test && npm run test:emulator` exits 0.
- [ ] The unit test asserting the absence of `email`, `emailVerified` and `deviceId` exists and passes.
- [ ] The emulator command of step 4 prints its target and `users=<n> memberships=<m>` and writes nothing; without `FORCE_BACKFILL=1` it exits non-zero.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Deploy the two triggers, then run both backfills, then confirm counts (`docs/numer2/USER_ACTIONS.md` B-3). P0-06 must not be deployed before this.

## Deliverable
Branch `numer2/p0-05-membership-index-profiles`, one commit, message `feat: add membership index and public profiles` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A `members` subcollection exists anywhere other than under `groups/{groupId}` (the collection group query would then need a filter).
- The client reads a peer field of `users/{uid}` that is not in the list in Context.
