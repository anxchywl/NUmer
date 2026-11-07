# P3-06: Study root

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-05

## Goal
Make Study the home of the course list and its timer sheet, with rows for Statistics,
History, Course analysis and study modules below it (`DESIGN.md` 4.3), and take the course
list, the add buttons and the AI button off Home.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 3.4, 3.5, 4.3, 5.1 to 5.4, 5.8, 6, 8 and 12 (binding)
- `docs/numer2/DECISIONS.md` D-20, D-34, D-35
- `lib/features/study/study_screen.dart` and `study.dart` (from P3-05)
- `lib/features/home/home_screen.dart` (after P3-04 and P3-05)
- `lib/features/courses/courses.dart` and `lib/features/courses/widgets/` (from P3-04):
  `CourseListSliver`, `showAddCourseSheet`
- `lib/features/sessions/sessions.dart`: `ActiveSessionBar`, `showCourseTimeSheet`
- `lib/features/ai_analysis/ai_analysis_screen.dart` (the coming-soon screen)
- `lib/app/shell/shell_tabs.dart`, `lib/app/modules/module_registry.dart`,
  `lib/core/modules/module_descriptor.dart`
- `test/features/courses/course_list_test.dart` (from P3-04, the fake `AppState`)

## Context
- After P3-05 the Study root is a header and two rows (D-35). Home still shows the course
  list, an empty-state add button, and two floating buttons (AI analysis and add course),
  drawn as `_IosLiquidActionPill` on iOS and `FloatingActionButton` on Android.
- `DESIGN.md` 3.5: the course list, reorder, swipe to delete and the goal popup move to
  Study unchanged; add course becomes the Study header action and the empty-state button;
  AI analysis becomes the row "Course analysis" with the status label "Coming soon"; the
  time sheet opens from a course row.
- Home keeps `FirstRunCreditsGate`, `AutoFinishWatcher` and `ActiveSessionBar` until P3-07
  rebuilds it. `AutoFinishWatcher` must stay mounted exactly once in the shell (Home is
  page 0 and is kept alive), so Study does not mount it.
- `NumerSection` takes a box child and `CourseListSliver` is a sliver, so the "Courses"
  section is drawn as slivers (step 2).
- Rows in one block either all have a leading icon or none (`DESIGN.md` 2.6). The "More"
  rows have none, module rows included.
- `noCoursesYet` ("No courses yet. Add a course from Home.") lost its only user when P3-05
  deleted `timer.dart`. This task gives it the `DESIGN.md` 8.2 text.
- Strings:

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `studyCoursesTitle` (new) | Courses | Курсы | Курстар |
  | `studyMoreTitle` (new) | More | Ещё | Тағы |
  | `comingSoon` (new) | Coming soon | Скоро | Жақында |
  | `noCoursesYet` (changed value) | No courses yet. | Курсов пока нет. | Әзірге курс жоқ. |

  Reuse `addCourse`, `statistics`, `history`, `courseAnalysis`, `navStudy`.

## Steps
1. `StudyScreen` gains `final List<ModuleDescriptor> modules` and `final void Function(
   ModuleDescriptor) onOpenModule`. `lib/app/shell/shell_tabs.dart` passes
   `visibleModules(ModuleSection.study, config, uid, registry: registry)` and `(d) =>
   openModule(context, d)`.
2. `StudyScreen.build`, top to bottom, inside one `CustomScrollView`, with
   `context.watch<AppState>()`:
   - `ShellHeader(title: Text(l10n.navStudy, style: context.text.screenTitle), actions:
     [IconButton(icon: const Icon(Icons.add), tooltip: l10n.addCourse, onPressed: () =>
     showAddCourseSheet(context))])`.
   - `const SliverToBoxAdapter(child: ActiveSessionBar())`.
   - The "Courses" section: `SliverToBoxAdapter(child: Padding(horizontal: NumerSpace.lg,
     child: Text(l10n.studyCoursesTitle, style: context.text.sectionTitle)))`,
     `SliverToBoxAdapter(child: SizedBox(height: NumerSpace.sm))`, then, when
     `state.courses` is empty, `SliverToBoxAdapter(child: NumerEmptyState(message:
     l10n.noCoursesYet, actionLabel: l10n.addCourse, onAction: () =>
     showAddCourseSheet(context), primaryAction: true))`, otherwise
     `CourseListSliver(onOpenCourse: (c) => showCourseTimeSheet(context, c))`. Then
     `SliverToBoxAdapter(child: SizedBox(height: NumerSpace.xl))`.
   - The "More" section: `SliverToBoxAdapter(child: NumerSection(title: l10n.studyMoreTitle,
     child: NumerBlock(children: [...])))` with, in order: `NumerRow(title:
     l10n.statistics, showChevron: true, onTap: push StatsScreen)`, `NumerRow(title:
     l10n.history, showChevron: true, onTap: push HistoryScreen())`, only when
     `state.courses.isNotEmpty` `NumerRow(title: l10n.courseAnalysis, trailing:
     NumerStatusLabel(l10n.comingSoon), onTap: push AiAnalysisScreen())`, then one
     `NumerRow(title: d.title(l10n), subtitle: d.subtitle(l10n), showChevron: true, onTap:
     () => onOpenModule(d))` per entry of `modules`. Every push uses `Navigator.of(context,
     rootNavigator: true)`.
   - Keep the bottom `SliverPadding` from P3-05.
   - The screen has no floating action button.
3. `HomeScreen` (`home_screen.dart`): delete the course list branch, the empty-state add
   button, `floatingActionButton`, `_fabVisible`, the `NotificationListener` that drives it,
   `_iosFabBottomLift`, `_openAddCourse` and `_IosLiquidActionPill`. Keep `ShellHeader`,
   `FirstRunCreditsGate`, `AutoFinishWatcher`, `ActiveSessionBar` and the bottom padding.
   Remove imports that become unused (`ai_analysis.dart`, `dart:ui` and others the analyzer
   names). Home is nearly empty until P3-07; that is expected.
4. Strings: add the three new keys and change the three values of `noCoursesYet` in
   `lib/l10n/app_en.arb`, `app_ru.arb`, `app_kk.arb`; run `flutter gen-l10n`.
5. Tests, `test/features/study/study_screen_test.dart` (extend the P3-05 file), with the fake
   `AppState` of `course_list_test.dart` extended for the header's avatar fields:
   - no courses: the empty-state text "No courses yet." and a `FilledButton` "Add course";
     no "Course analysis" row; Statistics and History rows present.
   - two courses: both names show; the "Course analysis" row shows with the status text
     "Coming soon" and no chevron; no empty state.
   - `modules` with one study descriptor: its row shows after Course analysis, with its
     subtitle; tapping it calls `onOpenModule` with it; its builder was not called.
   - `modules` empty: no row beyond the three.
   - The header add button has the tooltip "Add course".
   - The reorder and swipe-to-delete cases of `course_list_test.dart` still pass unchanged.
6. `test/features/home/home_screen_test.dart`: Home has no `FloatingActionButton` and no
   `CourseListSliver`.
7. Run `dart run scripts/check_design.dart --write-baseline` (removing the pill lowers the
   counts for `home_screen.dart`) and `./scripts/verify.sh`. No count may rise.
8. Screenshots (`DESIGN.md` 12): Study with no courses, with three courses, with a running
   session (the active session bar on top), and with a temporary study descriptor in the
   registry (not committed); light and dark, EN and RU; KK once; one at text scale 1.3.
   Also Home after this task, light mode, EN.

## Non-goals
- Do not change the course row, the time sheet, the goal popup, reorder or swipe to delete.
- Do not build Home's new layout (P3-07). Do not touch Statistics or History.
- No floating action on Study. No icons on the "More" rows.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. `scripts/check_file_size.sh` (in `verify.sh`) enforces it. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit; when it is split away, remove its entry. Never add a new path to the baseline.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (`docs/PRODUCT.md`: where courses and the timer are now).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The cases of steps 5 and 6 exist and pass.
- [ ] `grep -rn "_IosLiquidActionPill\|auto_awesome" lib/features/home` prints nothing.
- [ ] `grep -rn "FloatingActionButton" lib/features/study lib/features/home` prints nothing.
- [ ] Screenshots of step 8 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p3-06-study-root`, one commit, message `feat: move the course list to the study tab` (subject line only). Do not push.
Report: files changed, test output, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- `CourseListSliver` needs a change to work inside Study.
- The goal popup or the time sheet stops opening from a course row in Study.
- A string in the table collides with an existing key of a different meaning.
