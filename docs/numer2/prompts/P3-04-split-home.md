# P3-04: Split `home.dart` (no behaviour change)

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-12

## Goal
Break the 3098-line `lib/features/home/home.dart` into files owned by the features they
belong to, so P3-06 can put the course list in Study and P3-07 can rebuild Home. Nothing a
user can see or do changes.

## Read first
- `AGENTS.md` (feature layout, barrels, the dependency rule)
- `docs/numer2/DECISIONS.md` D-33 and D-34
- `lib/features/home/home.dart` (all of it)
- `lib/features/courses/courses.dart`, `lib/features/sessions/sessions.dart`,
  `lib/features/ai_analysis/ai_analysis.dart` (barrels)
- `lib/app/shell/shell_hooks.dart:1-15, 200-212` (imports `home.dart` for
  `showCourseTimeSheet`), `lib/app/shell/shell_tabs.dart:8,35`
- `test/boundaries/allowlist.txt`, `test/boundaries/layer_boundaries_test.dart`
- `scripts/check_design.dart`, `scripts/design_baseline.txt`
- `test/app/update_required_screen_test.dart` (the `noSuchMethod` fake pattern)

## Context
- Line numbers are from `main` at `5a6359c`. If the file changed, find each piece by name.
- What `home.dart` holds, by line:

  | Lines | Piece | Used by |
  |---|---|---|
  | 20-39 | `showCourseTimeSheet` | `HomeScreen`, `shell_hooks.dart:210` |
  | 41-55 | `_colorChoices` | add course sheet, edit course dialog |
  | 57 | `_kMaxSecs` (10800) | auto-finish watcher, active session bar, time sheet |
  | 59 | `_kDefaultSemesterWeeks` | goal popup |
  | 61-76 | `_hoursPerCreditForLevel` | course list, goal popup |
  | 78-93 | `_expShortLabel` | add course sheet, goal popup |
  | 95-101 | `_fmtHours` | goal popup |
  | 103-108 | `_fmtHMS` | course list, active session bar, time sheet |
  | 110-112 | `_courseNameWithoutParentheses` | auto-finish watcher, active session bar, time sheet |
  | 116-586 | `HomeScreen` and its state; the course list is lines 201-465 inside `build`; `_loadCourseSeconds` is 574-585 | shell |
  | 587-668 | `_IosLiquidActionPill` | `HomeScreen` |
  | 670-728 | `_SyncStatusChip` | `HomeScreen` |
  | 730-949 | `_AddCourseSheet` | `HomeScreen`, `_FirstRunCreditsGate` |
  | 951-962 | `_weeklyElapsedForCourse` | course list |
  | 964-1160 | `_openCreditsPopup` | course list |
  | 1162-1186 | `_popupRow` | goal popup |
  | 1188-1224 | `_CreditsBadge` | course list |
  | 1226-1299 | `_FirstRunCreditsGate` | `HomeScreen` |
  | 1301-1429 | `_AutoFinishWatcher` | `HomeScreen` |
  | 1431-1653 | `_ActiveSessionBar` | `HomeScreen` |
  | 1655-3051 | `_CourseTimeMenu` and its state; `_openEditCourseDialog` is 2133-2274 | `showCourseTimeSheet` |
  | 3053-3098 | `_StreakTitle` | `HomeScreen` |

- `_CourseTimeMenuState` alone is about 1400 lines. A Dart class cannot span files, and
  splitting it would mean changing how its methods reach its state. It moves whole into one
  file; only the edit course dialog leaves it (D-33). Every other new file stays under 700
  lines.
- `_openEditCourseDialog` uses `widget.course`, `_colorChoices`, `mounted` and ends with
  `setState(() {})` after saving (line 2264). As a top-level function it takes the course
  as a parameter, uses `context.mounted`, and the time sheet calls `setState` after it
  returns.
- The course list opens the time sheet. To keep `courses` from importing `sessions` while
  `sessions` imports `courses`, the list takes the action as a callback.
- `_IosLiquidActionPill` also exists, privately, in
  `lib/features/habits/screens/habits_screen.dart:927`. Leave both copies; P3-12 removes
  both.
- `scripts/check_design.dart` keys its baseline by file path, so moved code moves its counts.
  The per-pattern totals must not rise.
- The boundary test fails on a cross-feature import that bypasses a barrel, and on a stale
  allowlist line.

## Steps
1. Record the per-pattern totals before you start: `awk -F'\t' '{s[$1]+=$3} END {for (k in
   s) print k, s[k]}' scripts/design_baseline.txt | sort > /tmp/design_before.txt`.
2. Create these files and move the code into them. "Move" means cut and paste with only the
   renames and edits listed; keep every line of logic, every string, every duration.
   - `lib/features/courses/course_format.dart`: `courseColorChoices` (was `_colorChoices`,
     keep the colour comments), `hoursPerCreditForLevel`, `expShortLabel`, `formatHms` (was
     `_fmtHMS`), `courseNameWithoutParentheses`, `weeklyElapsedForCourse` (was
     `_weeklyElapsedForCourse`).
   - `lib/features/courses/widgets/course_list.dart`: `class CourseListSliver extends
     StatelessWidget` with `final ValueChanged<Course> onOpenCourse`. Its `build` returns
     the `SliverPadding` of `home.dart:201-465`, reading `context.watch<AppState>()` itself,
     with `_openCourseTimeMenu(context, c)` replaced by `onOpenCourse(c)` and
     `_loadCourseSeconds` moved in as a private method.
   - `lib/features/courses/widgets/course_goal_popup.dart`: `openCourseGoalPopup` (was
     `_openCreditsPopup`), `CreditsBadge` (was `_CreditsBadge`), and, private,
     `_kDefaultSemesterWeeks`, `_fmtHours`, `_popupRow`.
   - `lib/features/courses/widgets/add_course_sheet.dart`: `AddCourseSheet` (was
     `_AddCourseSheet`) and `Future<void> showAddCourseSheet(BuildContext context)`, which
     is the `showModalBottomSheet(context: context, isScrollControlled: true, builder: (_)
     => const AddCourseSheet())` that `HomeScreen._openAddCourse` (line 562) and
     `_FirstRunCreditsGateState._openAddCourseSheet` (line 1288) both build today. Both call
     sites call `showAddCourseSheet`.
   - `lib/features/courses/widgets/edit_course_dialog.dart`: `Future<void>
     showEditCourseDialog(BuildContext context, Course course)`, the body of
     `_openEditCourseDialog` with `widget.course` replaced by `course`, `mounted` by
     `context.mounted`, and the final `setState(() {})` removed. In the time sheet, the call
     becomes `await showEditCourseDialog(context, widget.course); if (mounted) setState(()
     {});`.
   - `lib/features/courses/widgets/first_run_credits_gate.dart`: `FirstRunCreditsGate` (was
     `_FirstRunCreditsGate`).
   - `lib/features/sessions/models/session_limits.dart`: `const int kMaxSessionSeconds =
     10800;` (was `_kMaxSecs`).
   - `lib/features/sessions/widgets/course_time_sheet.dart`: `showCourseTimeSheet` and
     `_CourseTimeMenu` with its state (stays private).
   - `lib/features/sessions/widgets/active_session_bar.dart`: `ActiveSessionBar` (was
     `_ActiveSessionBar`).
   - `lib/features/sessions/widgets/auto_finish_watcher.dart`: `AutoFinishWatcher` (was
     `_AutoFinishWatcher`).
   - `lib/features/home/streak_title.dart`: `StreakTitle` (was `_StreakTitle`).
   - `lib/features/home/sync_status_chip.dart`: `SyncStatusChip` (was `_SyncStatusChip`).
   - `lib/features/home/home_screen.dart`: `HomeScreen`, its state and
     `_IosLiquidActionPill`. In `build`, the course list branch becomes
     `CourseListSliver(onOpenCourse: (c) => showCourseTimeSheet(context, c))`. Delete
     `_openCourseTimeMenu` and `_loadCourseSeconds` (they moved). Delete the comment
     `// _savedSnack removed` (line 114), which describes code that no longer exists.
3. `lib/features/home/home.dart` becomes the barrel: a `// Public surface of the home
   feature.` comment line, then `export 'home_screen.dart';`.
4. Barrels: `lib/features/courses/courses.dart` adds exports for `course_format.dart` and
   the five files under `widgets/`; `lib/features/sessions/sessions.dart` adds
   `models/session_limits.dart` and the three new widget files. Keep existing exports.
5. Imports: every file imports another feature only through its barrel
   (`package:numer_app/features/<name>/<name>.dart`) and its own feature relatively.
   `home_screen.dart` imports `ai_analysis.dart`, `courses.dart`, `sessions.dart`.
   `lib/app/shell/shell_hooks.dart` drops the `home.dart` import (it already imports
   `sessions.dart`, which now holds `showCourseTimeSheet`). Remove imports that become
   unused (`flutter analyze` reports them).
6. `test/boundaries/allowlist.txt`: delete the three `lib/features/home/home.dart -> ...`
   lines. Add none. If the boundary test reports a new violation, fix the import, not the
   allowlist.
7. Run `dart run scripts/check_design.dart --write-baseline`, then compute the totals again
   into `/tmp/design_after.txt` and `diff /tmp/design_before.txt /tmp/design_after.txt`.
   Every total is equal or lower. Put the diff in the report.
8. Add `test/features/courses/course_list_test.dart`, a characterisation test of the moved
   list. Fake: `class _FakeAppState extends ChangeNotifier implements AppState` overriding
   `courses` (two courses), `homeSummaryRange` (`HomeSummaryRange.off`), `progressView`
   (`ProgressView.off`), `goalHoursForCourse` (null), `reorderCourses` and `removeCourse`
   (both record their arguments), and `noSuchMethod`. Pump `ChangeNotifierProvider<AppState>`
   > `MaterialApp` with the localization delegates > `CustomScrollView(slivers:
   [CourseListSliver(onOpenCourse: record)])`. Cases: both course names show in order;
   tapping the first row calls `onOpenCourse` with it; swiping a row shows the delete
   dialog and confirming calls `removeCourse` with its id, cancelling does not; a
   long-press drag of the first row below the second calls `reorderCourses`.
9. Run `./scripts/verify.sh`.
10. Check line counts: `wc -l lib/features/home/*.dart lib/features/courses/*.dart
    lib/features/courses/widgets/*.dart lib/features/sessions/models/session_limits.dart
    lib/features/sessions/widgets/*.dart`. Put the output in the report.

## Non-goals
- No redesign, no renamed string, no changed duration, no fixed bug. A bug you notice goes in
  the report, not in the diff.
- Do not split `_CourseTimeMenuState`. Do not touch `habits_screen.dart`.
- Do not change `swipeable_course_item.dart`, `course.dart`, `AppState` or any other feature.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`. (This task adds none and moves the hard-coded ones as they are.)
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji. Existing comments move with their code unchanged; fix only the one named in step 2.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0 (boundary test, design check and the new test included).
- [ ] `lib/features/home/home_screen.dart` is under 400 lines; every new file except `course_time_sheet.dart` is under 700 lines.
- [ ] `grep -rn "features/home/home.dart" test/boundaries/allowlist.txt` prints nothing, and the allowlist gained no line.
- [ ] `grep -rn "_kMaxSecs\|_fmtHMS\b\|_colorChoices" lib` prints nothing.
- [ ] The design totals diff shows no total higher than before.
- [ ] `git diff --stat` shows `home.dart` losing about 3090 lines and the new files gaining about the same; the report states the two numbers.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Run the smoke list in `docs/numer2/PLAN.md` ("The smoke list") on one Android and one iOS
  device before this is merged.

## Deliverable
Branch `numer2/p3-04-split-home`, one commit, message `refactor: split home into course and session widgets` (subject line only). Do not push.
Report: files changed with line counts, the design totals diff, test output, any bug noticed but not fixed, user actions still pending.

## Stop and ask if
- Moving a piece needs a change to its logic beyond the renames and the edits named in step 2.
- A private member of `_CourseTimeMenuState` is used outside the class (then the class cannot
  move whole as described).
- A design total rises.
