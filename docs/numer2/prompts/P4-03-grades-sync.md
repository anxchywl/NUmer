# P4-03: Grades: sync push and pull

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P4-02

## Goal
Sync the grade and semester records of P4-02 and the new course `code` between a user's
devices with the same offline-first rules as courses, so a transcript entered on one phone
appears on the other.

## Read first
- `AGENTS.md`, `docs/numer2/DECISIONS.md` D-25, D-33, D-42
- `lib/core/data/sync_service.dart:263-425` (`pushDirty`), `:427-463` (`pullSince`),
  `:719-835` (`_pullCollection`, `_applyRemoteCourse`), `:1262-1281` (`_courseToRemote`),
  `:1357-1368` (`_timestampToMs`)
- `lib/core/data/grade_entities.dart`, `local_database_grades.dart`, `grade_storage.dart`,
  `course_entity.dart` (from P4-02)
- `lib/features/auth/data/local_user_data.dart:6-12` (`hasUnsyncedChanges`)
- `functions/test/emulator/delete_account.test.ts:27-31` (the explicit subcollection list)
- `test/core/data/sync_service_test.dart`, `test/core/data/storage_courses_test.dart`

## Context
- Line numbers are from `main` at `e031f97` plus P4-02. Find code by name if it moved.
- The course pattern, which grades copy exactly:
  - push: `pushChunk` writes batches of at most 450 (`maxOperations`), `batch.set(ref,
    <toRemote>, SetOptions(merge: true))`, then `dirty = false` and `updatedAtMs = _now()`,
    then the records are saved; a soft-deleted course is pushed as a document with
    `deleted: true` (courses are not hard-deleted remotely);
  - pull: `_pullCollection(collection, stateKey, mapper, full, limit)` pages by the server
    `updatedAt` cursor stored under the sync-state key;
  - apply: a missing local record is created clean; a dirty local record whose
    `updatedAtMs` is not older than the remote wins and the remote is skipped; a dirty local
    record older than the remote logs a conflict (`logConflict(..., resolvedWithRemote:
    true)`) and takes the remote; whole-record last writer wins.
- `sync_service.dart` is 1416 lines and in the size baseline: it may only shrink (D-33).
  This task moves the course mapping out first: `_applyRemoteCourse`, `_courseToRemote`
  and `_timestampToMs` become public top-level functions in a new
  `lib/core/data/study_sync.dart`, next to the new grade and semester functions. The
  service keeps the batching, the cursors and the order of work. The pure functions take
  the database and the uid as arguments, so tests call them without a Firestore fake.
- Remote paths: `users/{uid}/courseGrades/{courseId}` and `users/{uid}/semesters/{id}`
  (rules from P4-02). Remote shapes:
  - grade: `{uid, semesterId, gradeLetter, assignments: [{id, name, weight, maximumScore,
    earnedScore}], deleted, updatedAt: serverTimestamp}`
  - semester: `{uid, name, position, deleted, updatedAt: serverTimestamp}`
  - course: today's map plus `code`.
- Account deletion removes the whole user tree with `recursiveDelete`
  (`functions/src/account/purge_user.ts:114-121`), so no function changes. The emulator test
  lists every subcollection it seeds and proves gone; it gains the two names.

## Steps
1. Create `lib/core/data/study_sync.dart` and move into it, as public top-level functions:
   - `int timestampToMs(Object? value)` (body of `_timestampToMs`);
   - `Map<String, dynamic> courseToRemote(LocalCourse course)` (body of `_courseToRemote`,
     plus `'code': course.code` after `'hiddenFromLeaderboard'`);
   - `Future<void> applyRemoteCourse(LocalDatabase db, {required String uid, required
     String id, required Map<String, dynamic> data})` (body of `_applyRemoteCourse` with
     `snapshot.id` -> `id`, `snapshot.data()` -> `data`, `_uid!` -> `uid`, `_db` -> `db`),
     plus `code: data['code'] as String?` in the create branch and `..code = data['code']
     as String?` in the update branch. Drop the second of the two identical `..goalHours`
     lines (`sync_service.dart:827-828`).
   In `SyncService` replace the three with calls to these functions; the `courses`
   `_pullCollection` call passes `mapper: (doc) => applyRemoteCourse(_db, uid: _uid!, id:
   doc.id, data: doc.data())`.
2. In `study_sync.dart` add, following `applyRemoteCourse` and `courseToRemote` line for
   line:
   - `Map<String, dynamic> courseGradeToRemote(LocalCourseGrade grade)` and
     `Map<String, dynamic> semesterToRemote(LocalSemester semester)` with the shapes above;
   - `Future<void> applyRemoteCourseGrade(LocalDatabase db, {required String uid, required
     String id, required Map<String, dynamic> data})`: assignments are parsed from the list
     of maps; an entry missing `id` or `name`, or with a non-number `weight` or
     `maximumScore`, is skipped; conflicts log `collection: 'courseGrades'`;
   - `Future<void> applyRemoteSemester(...)` the same, `collection: 'semesters'`.
3. `pushDirty`: after the goals block, before the `Future.wait` of saves, add two
   `pushChunk` calls for `_db.dirtyCourseGrades()` (path `courseGrades`) and
   `_db.dirtySemesters()` (path `semesters`), each `batch.set(..., SetOptions(merge:
   true))`, `dirty = false`, `updatedAtMs = _now()`; add both lists to that `Future.wait`
   as `.save()`.
4. `pullSince`: after the `courses` call add `_pullCollection(collection: 'courseGrades',
   stateKey: 'courseGrades', mapper: ..., full: full, limit: 250)` and the same for
   `semesters` with `limit: 200`. Add the state-key constants next to `_coursesStateKey`.
5. `hasUnsyncedChanges` (`local_user_data.dart:6-12`) also returns true for
   `db.dirtyCourseGrades().isNotEmpty || db.dirtySemesters().isNotEmpty`.
6. `functions/test/emulator/delete_account.test.ts:27-31`: add `'courseGrades'` and
   `'semesters'` to `subcollections`.
7. Lower the `sync_service.dart` entry in `scripts/file_size_baseline.txt` to its new count.
8. Tests in `test/core/data/study_sync_test.dart`, with a real `LocalDatabase` in a temp
   directory (pattern of `storage_courses_test.dart`) and `Timestamp` values:
   - `courseGradeToRemote` of a dirty grade with two assignments has every field and
     `updatedAt` is `FieldValue.serverTimestamp()`; `semesterToRemote` likewise.
   - push: a `SyncService` built with a hand-written `FirebaseFirestore` fake whose
     `batch()` records `set` calls by document path (extend the fakes of
     `sync_service_test.dart` in the new file, start the service with `start(uid: 'u',
     deviceId: 'd')`): after `pushDirty` one dirty grade produces one `set` at
     `users/u/courseGrades/<id>` and the local record is clean. If `start` needs fakes
     beyond those of `sync_service_test.dart` plus a recording `WriteBatch` and document
     paths, leave this one case out, say so in the report, and rely on the two-device check.
   - pull of a newer remote grade over a clean local one replaces it.
   - a dirty local grade with `updatedAtMs` newer than the remote is kept and no conflict
     is logged; one older than the remote takes the remote and logs one conflict with
     `collection: 'courseGrades'`.
   - a remote grade with `deleted: true` marks the local record deleted; a locally
     soft-deleted grade pushes `deleted: true`.
   - a remote assignment without `name` is skipped and the others are kept.
   - `applyRemoteCourse` with `code: 'CSCI 151'` stores the code; `courseToRemote` sends it.
   - the same newer, older and delete cases for a semester.
   No existing test in `test/core/data/` changes.
9. Run `./scripts/verify.sh` and `cd functions && npm run test:emulator`.

## Non-goals
- No change to how courses, sessions, goals or habits sync, beyond moving the course code.
- No peer read of grades: they are never added to `peer_courses` or group screens.
- No UI and no Gradus code.

## Constraints
- Offline-first contract: UI never writes Firestore. Sync is the only writer of these paths.
- Never renumber a Hive typeId or reorder adapter writes.
- Import a feature only through its barrel. Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit. Never add a new path to the baseline.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (the sync section of `docs/INFRASTRUCTURE.md` lists the synced collections).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0; `bash scripts/check_file_size.sh` prints nothing and `sync_service.dart` is shorter than 1416 lines.
- [ ] `cd functions && npm run test:emulator` passes with the two new names in the deletion test.
- [ ] `test/core/data/study_sync_test.dart` covers every case of step 8 and passes.
- [ ] `git diff main --stat -- test/core/data/sync_service_test.dart test/core/data/storage_courses_test.dart` prints nothing.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Two-device check after the rules of P4-02 are deployed: sign in on two devices, add a grade in GPA on one (after P4-04) or with a debug build, sync, and see it on the other.

## Deliverable
Branch `numer2/p4-03-grades-sync`, one commit, message `feat: sync course grades and semesters` (subject line only). Do not push.
Report: files changed, test output, the new `sync_service.dart` line count, user actions still pending.

## Stop and ask if
- Moving `_applyRemoteCourse` changes any behaviour of an existing course sync test.
- `pushDirty` or `pullSince` no longer has the shape described in Context.
