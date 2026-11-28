# P4-04: Mount Gradus: Hive transcript adapter, registry entry, flag

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P4-01, P4-03, P3-06, P2-03

## Goal
Show GPA as a row in the Study tab for users whose `gradus` flag is on. Gradus reads and
writes NUmer's own courses and grade records, works offline, and costs nothing at app
start.

## Read first
- `AGENTS.md`, `docs/DESIGN.md` sections 3.3, 3.4, 4.3, 9.5, 10 and 12 (binding)
- `docs/numer2/DECISIONS.md` D-23, D-24, D-25, D-42
- `lib/core/modules/module_descriptor.dart`, `lib/app/modules/module_registry.dart`,
  `lib/app/modules/open_module.dart`, `lib/core/identity/module_session.dart`,
  `lib/core/identity/id_token_provider.dart`
- `lib/core/config/app_config.dart` (94 lines), `lib/core/config/app_config_service.dart` (59)
- `lib/core/data/grade_storage.dart`, `grade_entities.dart` (P4-02)
- `lib/app/app_state.dart:1007-1034` (`addCourse`), `:1054-1100` (`removeCourse`),
  `:2478-2488` (`updateCourse`); `lib/features/courses/course.dart`
- `lib/features/study/study_screen.dart` (P3-06), `lib/app/shell/shell_tabs.dart`
- In Gradus at the P4-01 tag: `gradus_feature/lib/gradus_feature.dart`,
  `lib/src/domain/{course,assignment,semester,transcript,grade,repositories,errors}.dart`,
  `lib/src/application/gradus_controller.dart:132-260`
- `test/app/modules/module_registry_test.dart`, `test/app/modules/registry_is_empty_test.dart`,
  `scripts/measure_size.sh`

## Context
- Line numbers are from `main` at `e031f97`. Phase 3 files (`study/`, the new shell) come
  from P3-05 and P3-06; find code by name.
- `moduleRegistry` is `const` and empty. A `ModuleDescriptor` is const only if its function
  fields are top-level functions or static methods, so `title`, `subtitle` and `builder`
  are top-level functions in the feature folder.
- Gradus's controller keeps the transcript in memory, calls `TranscriptRepository.save(next)`
  with the whole next transcript after every edit, and restores the previous one when
  `save` throws (`gradus_controller.dart:238-253`). `load()` is called once when the
  screen opens.
- Gradus `Course` requires a non-empty `semesterId`, a title and `0 < credits <= 24`, and
  throws `InvalidCourseFailure` on a weight sum above 100 or a foreign assignment;
  `Assignment` throws `InvalidAssignmentFailure` on bad values; `FourPointScale.byLetter`
  throws for an unknown letter (`grade.dart:56`).
- Decisions for this adapter (D-42): GPA lists only NUmer courses that have a grade record;
  removing a course in GPA soft-deletes its grade record and keeps the NUmer course; a course
  added in GPA becomes a NUmer course with `day`, `start`, `end` empty, `colorValue:
  0xFF3B82F6` (the default of `Course.fromJson`) and `hiddenFromLeaderboard: true`.
- Module base URLs live in `config/app` as `modules.<id>.baseUrl`, an `https` URL (D-42).
  Gradus without one has no syllabus import (`GradusDependencies.syllabus` is null) and
  still works.
- Token contract: `ModuleSession.idToken` is the provider; `onSessionExpired` is `() async
  => await session.handleSessionExpired() != null`.
- `numer_ui` is a path dependency of NUmer (`pubspec.yaml:17-18`); Gradus depends on it by
  git, so NUmer overrides it.
- Strings:

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `moduleGradusTitle` | GPA | GPA | GPA |
  | `moduleGradusSubtitle` | Grades and GPA by semester | Оценки и GPA по семестрам | Семестр бойынша бағалар мен GPA |

## Steps
1. `pubspec.yaml`: add
   ```yaml
   gradus_feature:
     git:
       url: https://github.com/anxchywl/Gradus.git
       path: gradus_feature
       ref: v0.2.0
   ```
   and under `dependency_overrides` add `numer_ui: path: packages/numer_ui`. Run
   `flutter pub get`, then `cd ios && pod install` (Gradus brings `file_picker`) and keep the
   updated `ios/Podfile.lock`. `file_picker` opens the document picker on iOS, which needs no
   purpose string. Do not start before the Gradus tag `v0.2.0` exists (F-1).
2. Base URL in config: `ModuleFlag` gains `final Uri? baseUrl`, parsed in `_tryParse` from
   `raw['baseUrl']`: a `String` that `Uri.tryParse` accepts with scheme `https` and a
   non-empty host, otherwise null (a wrong value never drops the entry); `toJson` writes
   `'baseUrl': baseUrl?.toString()`. `AppConfigService` gains `Uri? moduleBaseUrl(String
   id) => _config.modules[id]?.baseUrl;`. Extend `test/core/config/app_config_test.dart`:
   https kept, `http://x` null, a number null, missing null, round trip through the cache.
3. Create `lib/features/gradus/` with barrel `gradus.dart` exporting `gradusModule` only.
4. `lib/features/gradus/hive_transcript_repository.dart`: `class HiveTranscriptRepository
   implements TranscriptRepository` with `HiveTranscriptRepository({required AppState
   appState, GradeScale scale = const FourPointScale()})` and a private `Transcript
   _current = Transcript.empty`.
   - `load()`: semesters from `GradeStorage.semesters()` as `Semester(id, name, position)`;
     for each `GradeStorage.courseGrades()` record whose id is a course in
     `appState.courses`, build the Gradus `Course` (`title` = course name, `credits` =
     course credits, `code` = `GradeStorage.courseCode(id) ?? ''`, `grade` =
     `scale.byLetter(letter)` or null when the letter is null or unknown, `assignments`
     from the record). Import Gradus as `import
     'package:gradus_feature/gradus_feature.dart' as gradus;` so its `Course`, `Assignment`
     and `Semester` do not clash with NUmer's. An assignment that throws
     `InvalidAssignmentFailure` is skipped. The rest are added one at a time in stored order:
     build the `gradus.Course` with the assignments kept so far plus the next one inside a
     `try`; on `InvalidCourseFailure` drop that assignment and go on (Gradus checks the weight
     budget in integer hundredths, so never sum doubles yourself). A letter that throws
     `UnknownGradeFailure` gives `grade: null`. A course is left out of the transcript, its
     records untouched, when its credits are null or outside `(0, 24]`, its name is blank,
     or its `semesterId` names no live semester. Store the result in
     `_current` and return it.
   - `save(Transcript next)`: compare `next` with `_current` by id and write only what
     differs, in this order: semesters added or changed (`putSemester`); courses added
     (`appState.addCourse(Course(...))` per Context, then `setCourseCode`, then
     `putCourseGrade`); courses changed (`appState.updateCourse(existing.copyWith(name:,
     credits:))` only when the title or credits differ, `setCourseCode` only when the code
     differs, `putCourseGrade` only when semester, letter or assignments differ); courses
     removed (`deleteCourseGrade`); semesters removed (`deleteSemester`). Set `_current =
     next` only after every write has completed. It never calls `Storage.saveCourses` or
     `appState.removeCourse`.
5. `lib/features/gradus/gradus_module.dart`:
   - top-level `String gradusTitle(AppLocalizations l10n) => l10n.moduleGradusTitle;`,
     `String gradusSubtitle(AppLocalizations l10n) => l10n.moduleGradusSubtitle;`,
     `NumerModuleScaffold buildGradusModule(BuildContext context) => NumerModuleScaffold(
     title: AppLocalizations.of(context)!.moduleGradusTitle, body: const GradusModuleBody())`;
   - `const ModuleDescriptor gradusModule = ModuleDescriptor(id: 'gradus', title:
     gradusTitle, subtitle: gradusSubtitle, icon: Icons.school_outlined, section:
     ModuleSection.study, flagId: 'gradus', builder: buildGradusModule);`
   - `class GradusModuleBody extends StatefulWidget`: in `initState` read `AppState`,
     `ModuleSession`, `AuthController` and `AppConfigService` with `context.read`, and
     build once: `GradusSession(idToken: session.idToken, accountId: <current uid>,
     onSessionExpired: ...)` and `GradusDependencies(transcript:
     HiveTranscriptRepository(appState: appState), scales: const
     StaticGradeScaleRepository(), syllabus: baseUrl == null ? null :
     createSyllabusImporter(baseUri: baseUrl, idToken: session.idToken, onSessionExpired:
     ...))` with `baseUrl = config.moduleBaseUrl('gradus')`. `build` returns
     `GradusFeature(session: ..., dependencies: ..., config: baseUrl == null ? const
     GradusConfig.sample() : GradusConfig.remote(baseUri: baseUrl), chrome:
     GradusChrome.host)`. If the uid is null, return `const SizedBox.shrink()`.
   `GradusFeature` stores `config` and never reads it (only `gradus_app/lib/main.dart:77`
   reads `baseUri`), so the dependencies alone decide what the feature talks to.
6. Registry: `lib/app/modules/module_registry.dart` lists `gradusModule`. Replace
   `test/app/modules/registry_is_empty_test.dart` with
   `test/app/modules/registry_order_test.dart`: the ids are `['gradus']`.
7. Strings: add the two keys to the three ARB files; run `flutter gen-l10n`.
8. Tests.
   Shared test setup for the module tests of this task: `Storage.configureForUser('u1')` over
     a temp directory (pattern of `storage_courses_test.dart`); a hand-written
     `class _FakeAuthController implements AuthController` with `noSuchMethod` and
     `currentUser` returning a `class _FakeUser implements User` whose `uid` is `'u1'`
     (`AuthController()` itself calls `FirebaseAuth.instance` and cannot be built in a test);
     the fake `AppState` below.
   - `test/features/gradus/hive_transcript_repository_test.dart`, with a real Hive in a temp
     directory and a fake `AppState` (hand-written subclass that records `addCourse` and
     `updateCourse` and keeps `courses` in memory). One test per controller edit, each
     through a real `GradusController(transcript: repo, scales: ...)`: add semester, rename
     semester, remove an empty semester; add course (a NUmer course with empty timetable
     fields, `hiddenFromLeaderboard: true`, the code stored); edit course title, credits,
     code and letter; remove course (grade record deleted, NUmer course still in
     `appState.courses`); add, edit and remove an assignment. After each, a second
     `HiveTranscriptRepository.load()` returns the same transcript.
   - In the same file: a stored unknown letter loads with `grade == null`; assignments
     weighing 60, 50 and 30 load as the 60 and 30 ones; a course with null credits, one with a blank
     name and one whose semester is deleted are left out and still stored; assignments
     weighing 33.34, 33.33 and 33.33 all load; an edit whose write throws (a fake `AppState.addCourse` that
     throws `HiveError`) leaves the controller on the previous transcript and `_current`
     unchanged, so the next save writes the course again.
   - `test/features/gradus/gradus_lazy_start_test.dart`: pump the Study root
     (`StudyScreen` with `visibleModules(ModuleSection.study, ...)` over the real
     registry, an `AppConfigService` whose cached config makes `gradus` visible for `u1`,
     a `ModuleSession` whose `idToken` counts its calls, the fake `AuthController` and the
     fake `AppState`). Before
     the GPA row is tapped: zero `idToken` calls and `find.byType(GradusModuleBody)` finds
     nothing (the repository and the controller are created only in its `initState`).
     After the tap: one `GradusModuleBody`. After going back: none, and still zero
     `idToken` calls (Gradus asks for a token only when a syllabus is imported).
   - `test/app/modules/registry_order_test.dart` (step 6).
9. Run `./scripts/verify.sh`.
10. Size: run `scripts/measure_size.sh` on `main` before the change and on the branch after
    it (release signing as described in the script); report both `apkDownloadBytes` values
    and the difference against the 1.0 MB budget (`DESIGN.md` 10).
11. Screenshots (`DESIGN.md` 12): with the flag on for the test account, the Study root
    with the GPA row; the GPA screen inside `NumerModuleScaffold` with two semesters, empty,
    and while loading; the course form while typing; light and dark, EN and RU; one at text
    scale 1.3.

## Non-goals
- No change to Gradus code (P4-01 owns it); no import from the standalone Gradus (O-5,
  P4-05 dropped).
- No change to how Study lists courses; no new tab.
- Do not set the `gradus` flag in any Firestore project.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/` (`GradeStorage`, `AppState`'s course methods) with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel. Direction is `features -> core -> shared`. `lib/features/gradus/` may import `lib/app/app_state.dart` and no other file under `lib/app/`.
- The module starts nothing before it is opened: no network call, storage read or controller at app start (`DESIGN.md` 10).
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- UI: only the tokens and components of `docs/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. A file listed in `scripts/file_size_baseline.txt` may only shrink. Never add a new path to the baseline.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file; the base URL comes from `config/app`.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (add `gradus` to the feature list in `AGENTS.md`; describe `baseUrl` where `docs/INFRASTRUCTURE.md` describes `config/app`).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The tests of steps 2 and 8 exist and pass; the lazy-start test asserts zero token calls and no `GradusModuleBody` before the tap.
- [ ] `grep -rn "saveCourses\|removeCourse" lib/features/gradus` prints nothing.
- [ ] The report gives both `apkDownloadBytes` values and the difference.
- [ ] Screenshots of step 11 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- `USER_ACTIONS.md` F-7: add `modules.gradus.baseUrl` (the Gradus backend `https` URL) to `config/app` in staging, then production.
- `USER_ACTIONS.md` F-2: open the `gradus` flag for your own uid first. Gradus stores nothing on a server, so it needs no account-events handler.
- If the Gradus repository is private, give NUmer's CI read access to it before merging.

## Deliverable
Branch `numer2/p4-04-mount-gradus`, one commit, message `feat: mount gradus in the study tab` (subject line only). Do not push.
Report: files changed, test output, the size numbers, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- `flutter pub get` cannot fetch `gradus_feature` at `v0.2.0`.
- `TranscriptRepository`, `StaticGradeScaleRepository` or `GradusIdToken` is not exported by the tagged package.
- The size grows by more than 1.0 MB.
