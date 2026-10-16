# P0-06: Firestore rules stage 1

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-05 (deployed and backfilled before these rules are deployed)

## Goal
Close every critical and high security finding that can be closed without breaking an app
version that is already installed. Today any signed-in user can become admin of any public
group, anyone on the internet can list every user's email, and peer access to study data is
decided by a field the reader controls.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-14 and D-15
- `firestore/firestore.rules` (all of it)
- `lib/features/groups/data/group_service.dart` lines 928-1118 and 1146-1276 (the exact payloads of create, join, leave, update group, change role)
- `lib/features/auth/data/auth_service.dart` lines 420-440, 805-835, 855-875, 895-925
- `lib/core/data/storage.dart` `Storage.addSession` and `lib/app/app_state.dart` `_addSessionSplitAcrossMidnight` (how long a saved session can be)
- `functions/test/rules/smoke.test.ts` (test style)

## Context
Installed versions cannot be changed. These are the writes they make; each must still pass:

- Create group, one batch: group document
  `{name, description, visibility, createdBy, createdAt, updatedAt, memberCount: 1}`; for a
  private group `groups/{id}/secrets/settings` `{joinCode}`; `groups/{id}/members/{uid}`
  `{role: 'admin', joinedAt: serverTimestamp}`; `users/{uid}/groupMemberships/{id}`
  `{role: 'admin', joinedAt}`; `users/{uid}` merge `{groupIds: arrayUnion(id)}`.
- Join a public group, one transaction: member `{role: 'member', joinedAt}`, membership
  `{role: 'member', joinedAt}`, user merge `{groupIds: arrayUnion}`, group update
  `{memberCount: current + 1, updatedAt: serverTimestamp}`.
- Leave: delete member, membership and `groups/{g}/aggregates/{uid}`; user merge
  `{groupIds: arrayRemove}`; group update `{memberCount: current <= 1 ? 0 : current - 1, updatedAt}`.
  An admin removing someone else does the same without the `groupIds` write.
- Sign-up, awaited: `email_index/{lowercased trimmed email}` merge
  `{uid, email, updatedAt}` while the new user is signed in and not yet verified. If this
  write is denied, sign-up reports a failure although the account exists.
- Password reset reads `email_index/{email}` and then `users/{uid}` without being signed in,
  inside a `try` whose `catch` ignores the failure and continues. Denying these reads is safe.
- Timer start and stop await a merge write of `activeSession`, `isStudying`, `lastActive` to
  `users/{uid}`. A user-document push (`_userToRemote`) that is denied stalls all sync. So
  the owner's write to `users/{uid}` must stay unrestricted in this stage.
- Session documents: `{uid, courseId, startUtc, endUtc, seconds, kind, notes, createdAt,
  deleted, updatedAt}`; a soft delete updates `{deleted: true, updatedAt}`. A denied session
  write stalls all sync, so session validation must be minimal.
- `/nudges` has no rule today, so the client's listener is always denied. It queries
  `where('receiverId', '==', uid).where('status', '==', 'pending')` and then updates
  `{status: 'delivered'}`.
- Session length is not clamped when saved: a timer left running across several midnights
  can store a piece longer than a day. The validation limit is therefore 604800 seconds (7
  days), which still stops the leaderboard exploit.
- `groupIndex` is written by a trigger a few seconds after a join. A peer read in that
  window is denied; the client already treats a failed peer read as "try later". Accepted.
- Some older group documents have no `memberCount` field.

The exploits to close (each needs a test that it is now denied):
1. C1: a non-member creates `groups/G/members/ATT` with `{role: 'admin'}` on a public group;
   a member updates their own member document to `role: 'admin'`; an admin changes
   `createdBy`.
2. C2: an unauthenticated client gets or lists `users`.
3. C3: anyone lists `email_index`; a signed-in user writes `email_index/victim@x`.
4. H1: a user sets `users/ATT.groupIds` to the victim's group and reads the victim's
   `sessions`, `courses` or `aggregates`.
5. H5: an unauthenticated client reads `users/V/aggregates/statistics`.
6. M5: a session with `seconds: 10000000`.

## Steps
1. Read the client payloads named in "Read first" and confirm each one against the Context list. Write any difference into the report before changing a rule.
2. Replace the helper `userGroupIds` and `hasSharedGroup` with:

   ```
   function groupIndexPath(userId) {
     return /databases/$(database)/documents/groupIndex/$(userId);
   }
   function indexedGroupIds(userId) {
     return exists(groupIndexPath(userId)) ? get(groupIndexPath(userId)).data.groupIds : [];
   }
   function hasSharedGroup(userId) {
     return isSignedIn() &&
       indexedGroupIds(request.auth.uid) is list &&
       indexedGroupIds(userId) is list &&
       indexedGroupIds(request.auth.uid).hasAny(indexedGroupIds(userId));
   }
   function groupData(groupId) {
     return get(/databases/$(database)/documents/groups/$(groupId)).data;
   }
   function groupExists(groupId) {
     return exists(/databases/$(database)/documents/groups/$(groupId));
   }
   function isGroupCreator(groupId) {
     return isSignedIn() && groupExists(groupId) && groupData(groupId).createdBy == request.auth.uid;
   }
   function isGroupPublic(groupId) {
     return groupExists(groupId) &&
       (!('visibility' in groupData(groupId)) || groupData(groupId).visibility == 'public');
   }
   function affected() {
     return request.resource.data.diff(resource.data).affectedKeys();
   }
   function memberCountStep() {
     let before = ('memberCount' in resource.data) ? resource.data.memberCount : 0;
     let after = ('memberCount' in request.resource.data) ? request.resource.data.memberCount : before;
     return after == before || after == before + 1 || after == before - 1 || (before <= 1 && after == 0);
   }
   function validSessionWrite() {
     let d = request.resource.data;
     return !('seconds' in d) || (d.seconds is number && d.seconds >= 0 && d.seconds <= 604800);
   }
   ```
   Keep `isSignedIn`, `isOwner`, `isGroupMember`, `isUserGroupMember`, `isGroupAdmin`,
   `isCreatingGroupAsOwner` and `isMemberSelfUpdatingCount` as they are.
3. Change these blocks. Everything not mentioned stays byte-for-byte.

   ```
   match /groups/{groupId} {
     allow read: (keep the existing line exactly)
     allow create: if isSignedIn()
       && request.resource.data.createdBy == request.auth.uid
       && request.resource.data.keys().hasOnly(
            ['name','description','visibility','createdBy','createdAt','updatedAt','memberCount'])
       && request.resource.data.memberCount == 1;
     allow update: if isSignedIn()
       && request.resource.data.createdBy == resource.data.createdBy
       && memberCountStep()
       && (
         (isGroupAdmin(groupId)
           && affected().hasOnly(['name','description','visibility','updatedAt','memberCount']))
         || isMemberSelfUpdatingCount(groupId)
       );
     allow delete: (keep the existing line exactly)

     match /members/{memberId} {
       allow read: (keep the existing line exactly)
       allow create: if isSignedIn() && memberId == request.auth.uid
         && request.resource.data.keys().hasOnly(['role','joinedAt'])
         && (
           (isCreatingGroupAsOwner(groupId) && request.resource.data.role == 'admin')
           || (isGroupCreator(groupId) && request.resource.data.role in ['admin','member'])
           || (isGroupPublic(groupId) && request.resource.data.role == 'member')
         );
       allow update: if isGroupCreator(groupId)
         && affected().hasOnly(['role'])
         && request.resource.data.role in ['admin','member'];
       allow delete: if isSignedIn() && (
         memberId == request.auth.uid
         || (isGroupAdmin(groupId) && memberId != groupData(groupId).createdBy)
       );
     }
     (invites, secrets, aggregates, stats, leaderboard: unchanged)

     match /{document=**} {
       allow delete: if isSignedIn() && isGroupAdmin(groupId) && document[0] != 'members';
     }
   }

   match /users/{userId} {
     allow get: if isSignedIn();
     allow list: if false;
     allow write: if isOwner(userId);
   }

   match /email_index/{emailId} {
     allow get, list: if false;
     allow create, update: if isSignedIn()
       && request.auth.token.email != null
       && emailId == request.auth.token.email.lower()
       && request.resource.data.uid == request.auth.uid;
     allow delete: if false;
   }

   match /users/{userId}/aggregates/{document=**} {
     allow read: if isOwner(userId) || hasSharedGroup(userId);
     allow write: if false;
     allow delete: if isOwner(userId);
   }

   match /users/{userId}/sessions/{sessionId} {
     allow read: if isOwner(userId) || hasSharedGroup(userId);
     allow create, update: if isOwner(userId) && validSessionWrite();
     allow delete: if isOwner(userId);
   }
   ```
   The `courses` block keeps its text; its `hasSharedGroup` now reads the index.
   The catch-all delete stays but no longer covers `members`, because rules are combined with
   OR and it would otherwise let any admin delete the creator's member document.

   Add these new blocks at the top level:

   ```
   match /nudges/{nudgeId} {
     allow read: if isSignedIn() && resource.data.receiverId == request.auth.uid;
     allow update: if isSignedIn() && resource.data.receiverId == request.auth.uid
       && affected().hasOnly(['status']) && request.resource.data.status == 'delivered';
     allow create, delete: if false;
   }
   match /publicProfiles/{userId} {
     allow get: if isOwner(userId) || hasSharedGroup(userId);
     allow list, write: if false;
   }
   match /groupIndex/{userId} {
     allow get: if isOwner(userId);
     allow list, write: if false;
   }
   match /config/{docId} {
     allow get: if isSignedIn();
     allow list, write: if false;
   }
   match /feed/{docId} {
     allow get: if isSignedIn();
     allow list, write: if false;
   }
   match /users/{userId}/aggState/{docId} { allow read, write: if false; }
   ```
   and one deny block, `allow read, write: if false;`, for each of these server-only
   collections: `nudgeLimits`, `joinAttempts`, `authCodes`, `authRateLimits`,
   `mailQueue`, `authAudit`, `deletedUsers`, `accountEvents`, `announcements`.
   Most of these collections are created by later tasks. Their names are fixed; do not search
   the code for them.
4. Check three things in the client and adjust the rule text only as stated:
   - `updateGroup` (`group_service.dart:1059-1118`): if it writes a key of the group document
     other than `name`, `description`, `visibility`, `updatedAt`, add that key to the admin
     list and say so in the report.
   - The role change method (search `role` writes in `group_service.dart:1146-1260`): if it
     writes keys other than `role` to the member document, add exactly those keys to the member
     `update` rule.
   - Session length: trace every caller of `Storage.addSession` and
     `_addSessionSplitAcrossMidnight`. If any path can save more than 604800 seconds in one
     session document, stop and ask.
5. Write `functions/test/rules/stage1.test.ts` with `@firebase/rules-unit-testing`. Seed with
   `withSecurityRulesDisabled`. One test per line:

   Denied:
   - each exploit in Context items 1 to 6 (12 assertions: item 1 has 3, item 2 has 2, item 3
     has 2, item 4 has 3, item 5 has 1, item 6 has 1);
   - an admin who is not the creator deletes the creator's member document;
   - a member joins a private group by creating their own member document;
   - a signed-in user reads `publicProfiles/V` without a shared group;
   - any client writes `publicProfiles`, `groupIndex`, `config/app`, `feed/current`,
     `authCodes/x`;
   - a receiver sets a nudge's `status` to anything but `delivered`; a non-receiver reads it;
   - a signed-in user lists `users`.

   Allowed (with the exact payloads from Context):
   - create a public group and a private group, each as one batch;
   - join a public group as one transaction; leave it;
   - the creator promotes a member to admin and demotes them;
   - an admin edits name and description; an admin edits the name of a group whose document
     has no `memberCount`; an admin removes a member (with the count update);
   - sign-up write: `authenticatedContext(uid, {email: 'Mixed@Case.com', email_verified:
     false})` sets `email_index/mixed@case.com` with `{uid, email, updatedAt}` and merge;
   - the owner writes `users/self` with `{groupIds: ['G'], activeSession: {...}, isStudying: true}`;
   - a signed-in user gets `users/other` (still allowed in this stage);
   - a co-member (both listed in `groupIndex`) reads the other's `sessions`, `courses`,
     `aggregates/statistics` and `publicProfiles` document;
   - the owner creates a session with the full field list and soft-deletes it;
   - the receiver lists their pending nudges with the query in Context and sets
     `status: 'delivered'`;
   - a signed-in user gets `config/app` and `feed/current`.
6. Update the Firestore rules paragraph in `AGENTS.md` and the data model list in `docs/INFRASTRUCTURE.md` so they match the new rules (which collections peers can read, which are server-only).
7. Run `cd functions && npm run test:emulator` and `./scripts/verify.sh`.
8. Add to the report a section "Deploy notes": the order (P0-05 deployed and backfilled first), the command `firebase deploy --only firestore:rules --project numer-60744`, and the rollback (republish the previous rules text from the console history).

## Non-goals
- Do not restrict what the owner may write to `users/{uid}` (no field deny-lists; see Context).
- Do not require a verified email anywhere (that is stage 2, P1-08).
- Do not close `email_index` writes completely, and do not make `users/{uid}` owner-only (stage 2).
- Do not remove the catch-all delete inside `groups/{groupId}` (stage 2); only exclude `members` from it as shown.
- Do not change `groupMemberships`, `secrets`, `invites`, `fcmTokens`, `nudgeCooldowns`, habits or any block not named.
- Do not change any client or function code. Do not deploy.

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
- Every `get()` and `exists()` in a rule costs a read; do not add one that the listed helpers do not need.
- A rule may use at most 10 document lookups for a single-document request and 20 for a batch or transaction; the group create batch must pass as one batch.

## Acceptance criteria
- [ ] `cd functions && npm run test:emulator` exits 0 with every test of step 5 present.
- [ ] `grep -n "userGroupIds" firestore/firestore.rules` prints nothing.
- [ ] `grep -n "if true" firestore/firestore.rules` prints nothing.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The report contains the payload comparison of step 1 and the three checks of step 4 with their results.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Deploy only after P0-05 is deployed and both backfills have run. Save the current rules first. Watch denied requests for 24 hours (`docs/numer2/USER_ACTIONS.md` B-4).

## Deliverable
Branch `numer2/p0-06-rules-stage-1`, one commit, message `fix: tighten firestore rules stage 1` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- Any installed-version payload differs from Context in a way a rule above would reject.
- The client lists or queries the `users` collection anywhere (`grep -rn "collection('users')" lib` followed by `.where` or `.get()` on the collection).
- A member legitimately updates their own member document.
- An earlier version of the client wrote other keys to `groups/{g}/members/{uid}` or to the group document (check `git log -S"'joinedAt'" -- lib/features/groups` and the diffs it lists).
- `document[0]` is not accepted by the rules emulator for the recursive wildcard.
- A group role label other than `admin` and `member` exists in `lib/features/groups/models/`.
- The group create batch exceeds the lookup limit in the emulator.
