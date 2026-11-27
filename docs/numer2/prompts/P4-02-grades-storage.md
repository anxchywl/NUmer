# P4-02: Grades: Hive types 18 to 20, storage, rules

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-06

## Goal
Give NUmer owner-only local records for course grades, assignments and semesters, so that
Gradus can store a transcript in NUmer's offline-first database (D-25) without putting
grades on the course document that group peers can read.

## Read first
- `AGENTS.md` ("Agent Gotchas" on Hive, "Size")
- `docs/numer2/DECISIONS.md` D-25, D-33, D-42, section F row "Hive"
- `lib/core/data/entities.dart:1-20` (`SyncEntity`), `:137-214` (`LocalCourse`), `:634-684`
  (`LocalCourseAdapter`)
- `lib/core/data/local_database.dart` (398 lines, whole file)
- `lib/core/data/storage.dart:1-75` and `:455-603` (the course methods)
- `scripts/file_size_baseline.txt`, `scripts/check_file_size.sh`
- `firestore/firestore.rules:236-263`, `functions/test/rules/feed.test.ts` (test pattern)
- `test/core/data/storage_courses_test.dart` (the temp-directory Hive test pattern)

## Context
- Line numbers are from `main` at `e031f97`. Find code by name if it moved.
- Typed ids in use: 10 `LocalUserDoc`, 11 `LocalCourse`, 12 `LocalSession`, 13 `LocalGoal`,
  14 `SyncStateEntry`, 15 `LocalConflict`, 16 `LocalHabit`, 17 `LocalHabitHistory`. No id
  above 17 exists in `lib/` or `packages/` (`grep -rn "typeId" lib packages`).
- Adapters are hand-written and positional. A new field is an appended write and a guarded
  read (`reader.availableBytes > 0 ? ... : default`), exactly as `sortOrder` and
  `hiddenFromLeaderboard` at `entities.dart:658-661`.
- Size rule (D-33): `entities.dart` (922), `storage.dart` (1508) and `sync_service.dart`
  (1416) are in the baseline and may only shrink. `local_database.dart` is 398 lines with a
  limit of 400. So this task moves code out before adding code:
  - `LocalCourse` and `LocalCourseAdapter` move verbatim to a new
    `lib/core/data/course_entity.dart`, re-exported from `entities.dart`;
  - the habit and habit-history members of `LocalDatabase` (`local_database.dart:335-385`)
    move to a `part` file, where they keep access to the private boxes;
  - the course bodies of `Storage` move to a new `CourseStorage`, and `Storage` keeps
    one-line forwarders so no caller changes.
- Facts the executor confirms and writes into the report before coding (D-42 records the
  expected answers): no screen reads `Course.day`, `start` or `end` except the course
  model and storage (`grep -rnE "\.(day|start|end)\b" lib/features` shows only date and
  layout uses), and `shell_hooks.dart` already builds a `Course` with empty timetable
  fields; `credits` is a `double?` holding ECTS credits ("6 or 7 for example",
  `app_en.arb:121`); course ids are `'<epoch ms>_<0..9998>'` (`add_course_sheet.dart:245`).
- Record shapes (D-25, D-42):

  | Type | typeId | Fields, in write order |
  |---|---|---|
  | `LocalCourseGrade` (`SyncEntity`, key = course id) | 18 | `id`, `uid`, `updatedAtMs`, `dirty`, `deleted`, `semesterId` (String), `gradeLetter` (String?), `assignments` (List<LocalAssignment>) |
  | `LocalAssignment` (plain, embedded) | 19 | `id`, `name`, `weight` (double), `maximumScore` (double), `earnedScore` (double?) |
  | `LocalSemester` (`SyncEntity`) | 20 | `id`, `uid`, `updatedAtMs`, `dirty`, `deleted`, `name`, `position` (int) |

  `LocalCourse` gains `String? code`, field 17, written after `hiddenFromLeaderboard`.
- Boxes: `${uid}_course_grades` (`Box<LocalCourseGrade>`) and `${uid}_semesters`
  (`Box<LocalSemester>`).

## Steps
1. Create `lib/core/data/course_entity.dart` and move `LocalCourse` (`entities.dart:137-214`)
   and `LocalCourseAdapter` (`:634-684`) into it unchanged. It imports `package:hive/hive.dart`
   and `entities.dart` (for `SyncEntity`). Add `export 'course_entity.dart';` to
   `entities.dart` after its imports. Lower the `entities.dart` entry in
   `scripts/file_size_baseline.txt` to its new line count.
2. In `course_entity.dart` add `@HiveField(17) String? code;` with the constructor parameter
   `this.code`. In the adapter append `..write(obj.code)` after
   `..write(obj.hiddenFromLeaderboard)` and read `code: reader.availableBytes > 0 ?
   reader.read() as String? : null` after `hiddenFromLeaderboard`. Nothing else in the
   adapter changes.
3. Create `lib/core/data/grade_entities.dart` with the three classes of the table (the two
   sync entities `extends HiveObject with SyncEntity`, `LocalAssignment extends HiveObject`)
   and `LocalCourseGradeAdapter` (18), `LocalAssignmentAdapter` (19), `LocalSemesterAdapter`
   (20), with `@HiveType(typeId: ...)` and `@HiveField(n)` annotations numbered in table
   order, like the existing classes. Each adapter writes the fields in table order and reads them in the same order;
   `assignments` is written with `writer.write(obj.assignments)` and read as
   `(reader.read() as List).cast<LocalAssignment>().toList()`. Constructors default
   `dirty = true` and `deleted = false`; `LocalCourseGrade` takes `List<LocalAssignment>?
   assignments` and stores `assignments ?? []` through its initializer list, so the stored
   list is never a constant.
4. `lib/core/data/local_database.dart`:
   - Add `part 'local_database_habits.dart';` and move `local_database.dart:335-385` into
     that file as `extension LocalDatabaseHabits on LocalDatabase { ... }`, members
     unchanged (they read `_habitsBox` and `_habitHistoryBox`, which a part may reach).
   - Add `part 'local_database_grades.dart';` with `extension LocalDatabaseGrades on
     LocalDatabase` holding: `Iterable<LocalCourseGrade> courseGrades({bool includeDeleted
     = false})`, `List<LocalCourseGrade> dirtyCourseGrades()`, `LocalCourseGrade?
     getCourseGradeById(String id)`, `Future<void> putCourseGrade(LocalCourseGrade g)`, and
     the same four for semesters (`semesters`, `dirtySemesters`, `getSemesterById`,
     `putSemester`), each written like its course counterpart (`local_database.dart:115-146,194-198`).
   - In the class: fields `Box<LocalCourseGrade>? _courseGradesBox` and
     `Box<LocalSemester>? _semestersBox`; open both in `openForUser` as `results[11]` and
     `[12]`; close and null them in `close`; clear them in `clearAll`; delete
     `'${uid}_course_grades'` and `'${uid}_semesters'` in `deleteBoxesForUser`; register the
     three new adapters inside `_registerAdapters` after `LocalHabitHistoryAdapter()`.
   - If any test fake `implements LocalDatabase` and overrides a moved habit member, delete
     that override (extension members cannot be overridden).
   The file must end under 400 lines.
5. Create `lib/core/data/course_storage.dart` with `abstract final class CourseStorage`
   holding the bodies of `Storage._mapCourses`, `getCourses`, `saveCourses`, `deleteCourse`,
   `_compareCourseOrder` and `_ensureCourseOrder` (`storage.dart:458-603`), moved unchanged
   except that `_db`, `_now` and `_ensureUser` become private copies in `CourseStorage`.
   In `Storage` replace them with `static Future<List<Course>> getCourses() =>
   CourseStorage.getCourses();`, `static Future<void> saveCourses(List<Course> courses) =>
   CourseStorage.saveCourses(courses);` and `static Future<void> deleteCourse(String id) =>
   CourseStorage.deleteCourse(id);`. Lower the `storage.dart` baseline entry. `CourseStorage`
   imports `Course` as `storage.dart` does: add the line
   `lib/core/data/course_storage.dart -> lib/features/courses/course.dart` to
   `test/boundaries/allowlist.txt`, the same exception `storage.dart` already has.
6. Create `lib/core/data/grade_storage.dart` with `abstract final class GradeStorage` (each
   method throws `StateError` like `Storage._ensureUser` when no user is open):
   - `static List<LocalCourseGrade> courseGrades()` and `static List<LocalSemester>
     semesters()`: non-deleted records.
   - `static Future<void> putCourseGrade({required String courseId, required String
     semesterId, required String? gradeLetter, required List<LocalAssignment>
     assignments})`: creates the record (`dirty: true`, `updatedAtMs: now`) or, when one
     exists, assigns the fields and saves with `dirty = true`, `deleted = false` and
     `updatedAtMs = now` only if a field differs (two assignment lists differ unless they
     have the same length and equal `id`, `name`, `weight`, `maximumScore`, `earnedScore`
     at each index).
   - `static Future<void> deleteCourseGrade(String courseId)`: soft delete like
     `deleteCourse`; nothing when absent or already deleted.
   - `static Future<void> putSemester({required String id, required String name, required
     int position})` and `static Future<void> deleteSemester(String id)`, same rules.
   - `static String? courseCode(String courseId)` and `static Future<void>
     setCourseCode(String courseId, String? code)`: reads and writes `LocalCourse.code`,
     saving with `dirty = true` and `updatedAtMs = now` only when it differs.
   `now` is `DateTime.now().toUtc().millisecondsSinceEpoch`, as in `Storage._now`.
7. `CourseStorage.deleteCourse` also calls `GradeStorage.deleteCourseGrade(id)` in the same
   call, after marking the course. `saveCourses` never reads or writes `code`.
8. Rules: after the `courses` block in `firestore/firestore.rules` add
   ```
   match /users/{userId}/courseGrades/{courseId} {
     allow read, write: if isOwner(userId);
   }

   match /users/{userId}/semesters/{semesterId} {
     allow read, write: if isOwner(userId);
   }
   ```
9. Tests:
   - `test/core/data/grade_entities_test.dart`: round trip of each new adapter through a
     real box in a temp directory (pattern of `storage_courses_test.dart`), including a
     grade with two assignments and a null `gradeLetter`, and an assignment with a null
     `earnedScore`.
   - `test/core/data/course_entity_test.dart`: a `LocalCourse` written by a copy of the old
     adapter (a test-only class writing the 17 fields without `code`, typeId 11) is read by
     `LocalCourseAdapter` with `code == null` and every other field equal; a course with
     `code: 'CSCI 151'` round-trips. Mechanism: `Hive.init(<temp dir>)`, `Hive.resetAdapters()`,
     register only the legacy adapter, open a box, put a course, close it; `Hive.resetAdapters()`
     again, register the real adapters, reopen the box and read.
   - `test/core/data/type_ids_test.dart`: the `typeId` of each of the eleven adapters is
     pinned: 10 to 17 to the existing classes, 18, 19, 20 to the new ones.
   - `test/core/data/grade_storage_test.dart`: put then read; a second put with equal
     values leaves `dirty` false after the test clears it and does not change `updatedAtMs`;
     a changed assignment marks dirty; soft delete; `Storage.deleteCourse` soft-deletes the
     grade record of that course and leaves another course's record; `setCourseCode` marks
     the course dirty and `Storage.saveCourses` with a `Course` keeps the code.
   - `functions/test/rules/grades.test.ts` (pattern of `feed.test.ts`): the owner reads and
     writes both paths; another signed-in user who shares a group with the owner (seed
     `groupIndex/<uid>` for both, as `stage1.test.ts:40-70`) cannot read or write either;
     an unauthenticated client cannot read.
10. Run `./scripts/verify.sh`, and `cd functions && npm run test:emulator` for the rules test.

## Non-goals
- No sync (P4-03), no UI, no Gradus code (P4-04).
- Do not add `code` to the `Course` model or to `saveCourses`; only `GradeStorage` touches it.
- Do not change any existing adapter's read or write order.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Import a feature only through its barrel. Direction is `features -> core -> shared`; `lib/core/data/` gains no new import from `lib/features/` except the allowlisted line of step 5.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit. Never add a new path to the baseline.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (add `courseGrades` and `semesters` to the user subcollections listed in `docs/INFRASTRUCTURE.md`).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0; `bash scripts/check_file_size.sh` prints nothing.
- [ ] `cd functions && npm run test:emulator` passes, including `test/rules/grades.test.ts`.
- [ ] The five test files of step 9 exist and pass; `type_ids_test.dart` pins all eleven ids.
- [ ] `git diff main -- lib/core/data/course_entity.dart` compared with the removed lines of `entities.dart` shows only the `code` field, its constructor parameter and its two adapter lines as new.
- [ ] The report states the three facts of Context with the command output that shows them.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Deploy the rules with the next rules deploy (`USER_ACTIONS.md` B-4 procedure); nothing writes these paths until P4-03 ships.

## Deliverable
Branch `numer2/p4-02-grades-storage`, one commit, message `feat: add local grade and semester records` (subject line only). Do not push.
Report: files changed, the three facts, test output, user actions still pending.

## Stop and ask if
- A `typeId` above 17 is already used anywhere in `lib/`, `packages/` or a dependency's registered adapters.
- Moving the habit members into a part file breaks a caller outside `lib/core/data/` in a way an import cannot fix.
- `local_database.dart` cannot get under 400 lines with the moves above.
