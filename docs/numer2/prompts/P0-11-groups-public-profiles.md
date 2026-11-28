# P0-11: Groups: public profiles and listener hygiene on the client

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-05, P0-10

## Goal
The groups feature reads other users' full `users/{uid}` documents (which contain their
email), writes to Firestore from inside a stream, and creates listeners inside `build`.
Read peers from `publicProfiles` instead, remove the side effect, and create each listener
once. This is the client half of closing the email leak; stage 2 rules need it shipped.

## Read first
- `AGENTS.md`
- `docs/numer2/DECISIONS.md` D-15
- `lib/features/groups/groups.dart` (the barrel)
- `lib/features/groups/data/group_service.dart` lines 10-110, 130-350, 460-500, 640-770, 840-930
- `lib/features/groups/data/group_aggregation_service.dart` (all of it)
- `lib/features/groups/models/` (all files, in particular `sessionRunUntil` in `group_statistics.dart`)
- `lib/features/groups/screens/groups_screen.dart` lines 30-140, `create_group_screen.dart` lines 220-260, `manage_group_screen.dart` lines 345-400, 480-510 and 800-810
- `lib/features/groups/widgets/group_leaderboard.dart` lines 530-560 and 680-700, `user_subjects_bottom_sheet.dart` lines 50-150
- `lib/shared/widgets/universal_avatar.dart`, `lib/shared/widgets/user_profile_tile.dart`
- `lib/features/account/screens/account.dart` lines 220-235
- `lib/main.dart` lines 165-200 (providers)

## Context
- `publicProfiles/{uid}` (server-written, readable by the owner and by members of a shared
  group) has exactly these fields: `profileName` (string), `major`, `profileGoal`,
  `profileContact` (string or null), `avatarIndex` (int or null), `avatarColorValue` (int or
  null), `avatarImageBase64` (string or null), `isStudying` (bool), `activeSession` (null or
  a map `{courseId, kind, startUtc, expectedEndUtc}` whose two time values are Firestore
  `Timestamp`s, copied as they are in `users/{uid}`), `allowNudges` (bool), `fcmEnabled`
  (bool), `updatedAt`.
- Places that read another user's `users/{id}` today:
  1. `universal_avatar.dart:49-63`: a `StreamBuilder` created inside `build`.
  2. `user_profile_tile.dart:24-39` (it also shows the hard-coded text `Anonymous User`).
  3. `user_subjects_bottom_sheet.dart:73-91`.
  4. `group_service.dart:253-262` (`updateMemberListeners`, one listener per member) and
     `updatePresence` (`:176-244`), which returns early when the snapshot does not exist.
  5. `group_service.dart:466-493` (`fetchAndCacheMemberProfile`), which stores a map in a
     local profile cache.
  6. `group_aggregation_service.dart:123, 207, 350, 510`. Only `memberFromAggregateData`
     (`:414`) of that file is used by the rest of the app.
- Existing code reads these keys from the user document or the cached map:
  `profileName`, `major`, `profileGoal`, `profileContact`, `profileAvatarIndex` (falling back
  to `avatarIndex`), `profileAvatarImageBase64`, `avatarColorValue` (falling back to
  `profileAvatarColorValue`), `isStudying`, `activeSession`, `allowNudges`, `fcmEnabled`.
- `watchUserMemberships` (`group_service.dart:75-91`) writes `users/{uid}.groupIds` inside
  the stream's `.map`, on every emission, and the stream is built inside `build`
  (`groups_screen.dart:62`). The public-groups and search streams are also created in
  `build` (`groups_screen.dart:78-81`). The server maintains membership itself now; the
  write is no longer needed.
- `watchPublicGroups` (`group_service.dart:33-37`) has no limit.
- Create group already rejects a private-group code shorter than 4 characters, with a
  hard-coded English toast (`create_group_screen.dart:229-236`). The manage screen pre-fills
  the current code and only checks that it is not empty (`manage_group_screen.dart:364-371`,
  `:804-809`).
- `GroupService()` builds `FirebaseFirestore.instance` in its constructor, so screens that
  need it cannot be pumped in a widget test. Test pure functions and widgets that take their
  data as parameters.
- `lib/shared/` must be pure UI: no Firestore and no feature imports.

## Steps
1. Add `lib/features/groups/models/public_profile.dart`: an immutable `PublicProfile` with the
   fields above (`activeSession` typed `Map<String, dynamic>?`, kept as received) and
   `factory PublicProfile.fromMap(String uid, Map<String, dynamic> data)`. Add
   `Map<String, dynamic> toLegacyProfileMap()` returning the keys the existing code reads:
   `profileName`, `major`, `profileGoal`, `profileContact`, `profileAvatarIndex` and
   `avatarIndex` (both from `avatarIndex`), `profileAvatarImageBase64` (from
   `avatarImageBase64`), `avatarColorValue` and `profileAvatarColorValue` (both from
   `avatarColorValue`), `isStudying`, `activeSession`, `allowNudges`, `fcmEnabled`.
2. Add `lib/features/groups/data/public_profile_source.dart`:
   `abstract class PublicProfileSource { Stream<PublicProfile?> watch(String uid); Future<PublicProfile?> fetch(String uid); }`
   (null means the document does not exist) and `FirestorePublicProfileSource` reading
   `publicProfiles/{uid}`. `GroupService` takes an optional source in its constructor,
   defaulting to the Firestore one. Register `Provider<PublicProfileSource>` in `lib/main.dart`
   next to the `GroupService` provider, sharing the same instance, and export the new types
   from the groups barrel.
3. Change readers 3, 4 and 5 to use the source, feeding the existing code through
   `toLegacyProfileMap()` so the types and keys above them do not change. A null profile is
   handled exactly as a non-existent snapshot is handled today (`updatePresence` returns
   early; `fetchAndCacheMemberProfile` returns null). An empty `profileName` is treated as
   missing.
4. `UniversalAvatar` (reader 1): remove Firestore and `userId` from the widget. It keeps its
   other parameters (`name`, `size`, `fontSize`, `alwaysShowSilhouette`) and takes
   `avatarIndex`, `avatarColorValue` and `avatarImageBase64` as data. Because it needs the
   avatar catalogue of `features/account`, move it to
   `lib/features/account/widgets/universal_avatar.dart` and export it from the account barrel.
   Update its call sites (`group_leaderboard.dart:549, 692`,
   `user_subjects_bottom_sheet.dart:143`, the profile tile, `account.dart:229`): leaderboard
   rows and the member sheet pass the values they already hold; the Settings identity card
   passes the signed-in user's own values from `AppState`.
5. `UserProfileTile` (reader 2): move it to `lib/features/groups/widgets/user_profile_tile.dart`. It takes a `PublicProfileSource` from `context.read`, creates its stream in `initState`, shows `profileName`, and when the profile or the name is missing shows `memberFallbackName` (step 9) in place of `Anonymous User`. It no longer reads `displayName`.
6. Reader 6: in `group_aggregation_service.dart` delete every method with no caller outside the file (expected: `computeGroupStatistics`, `computeMemberStats`, `fetchMemberSubjectStats`, `_emptyMemberData`, `_readAggregate` and their private helpers), confirming each with `grep -rn`. Keep `memberFromAggregateData` and what it needs. The method of the same name `fetchMemberSubjectStats` in `group_service.dart` stays. Remove imports that become unused.
7. `watchUserMemberships`: remove the `groupIds` write. In `groups_screen.dart` create the memberships stream, the public-groups stream and the search stream in state (`initState`, and again only when the debounced query changes), never in `build`. The uid comes from the same source the screen uses today; keep its signed-out early return.
8. `watchPublicGroups`: add `.limit(50)`. Debounce the search text by 300 ms with one `Timer` that is cancelled in `dispose`.
9. A member without a profile: show the name from the aggregate document when present,
   otherwise a new string `memberFallbackName` (EN `Member`, RU `Участник`, KK `Мүше`), and the
   default avatar.
10. Join code length. Add a pure top-level function in the groups feature:
   `bool isJoinCodeLongEnough(String code) => code.trim().length >= 8;`
   - `create_group_screen.dart`: replace the `< 4` check at lines 229-236 with this function
     and the English literal with a new string `joinCodeTooShort` (EN `Use at least 8
     characters.`, RU `Используйте не меньше 8 символов.`, KK `Кемінде 8 таңба қолданыңыз.`).
   - `manage_group_screen.dart`: keep the loaded code in a field; apply the length check in
     the validator only when the text differs from the loaded code, so a group with an older
     short code can still save other changes.
   Existing shorter codes keep working for joining.
11. Tests:
   - `test/features/groups/public_profile_test.dart`: `fromMap` with a full map and with an
     `activeSession` map; `toLegacyProfileMap` has exactly the listed keys and passes a
     `Timestamp` through unchanged.
   - `test/features/groups/join_code_test.dart`: 7 characters is too short, 8 is enough,
     surrounding spaces do not count.
   - `test/features/groups/user_profile_tile_test.dart` with a hand-written
     `FakePublicProfileSource` provided through `Provider`: a profile shows its name; a null
     profile shows the fallback name.
12. In `test/boundaries/allowlist.txt` remove the lines that are no longer violations (the test fails if a stale line remains). Run `./scripts/verify.sh`.

## Non-goals
- Do not stop the `groupIds` writes inside the create, join and leave batches (installed and new versions both keep them; they are harmless).
- Do not change the leaderboard's look, ordering or the nudge flow.
- Do not change `firestore/firestore.rules` or any function.
- Do not restyle screens; only the two new strings, the fallback name and the debounce are visible changes.

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
- Streams are created in `initState` or in a service, never in `build`.

## Acceptance criteria
- [ ] `grep -rn "cloud_firestore" lib/shared` prints nothing.
- [ ] `grep -rn "features/" lib/shared` prints nothing.
- [ ] `grep -rn -A4 "collection('users')" lib/features/groups | grep -E "\.(snapshots|get)\("` shows only reads of the signed-in user's own documents; the report lists each remaining line with its reason.
- [ ] `grep -rn "Anonymous User\|at least 4 characters" lib` prints nothing.
- [ ] The three test files pass.
- [ ] `./scripts/verify.sh` exits 0, including the boundary test.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Open a real group's leaderboard and check names, avatars and the studying indicator (`docs/numer2/USER_ACTIONS.md` B-3 must be done first).

## Deliverable
Branch `numer2/p0-11-groups-public-profiles`, one commit, message `refactor: read group peers from public profiles` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A widget needs a peer field that `publicProfiles` does not have, other than `displayName`.
- A method in `group_aggregation_service.dart` that looks unused is reached through a tear-off or a stream you cannot trace.
- Removing the `groupIds` write from the stream changes what a screen shows.
- No line of `allowlist.txt` becomes stale (then something was not moved as described).
