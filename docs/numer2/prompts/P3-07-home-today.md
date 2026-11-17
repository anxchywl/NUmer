# P3-07: Home: today layout

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-06

## Goal
Make Home the today screen of `DESIGN.md` 4.1: streak header, running session, a Today block
for study and habits, and one button that gets the user back into studying in one tap
(D-20). Upcoming (P3-10) and News (P3-09) slot in below later.

## Read first
- `AGENTS.md` (state hydration rules)
- `docs/numer2/DESIGN.md` sections 4.1, 5.1 to 5.4, 5.7, 6, 7.2, 8 and 12 (binding)
- `docs/numer2/DECISIONS.md` D-20, D-21, D-34
- `lib/features/home/home_screen.dart`, `streak_title.dart`, `sync_status_chip.dart`
  (after P3-06)
- `lib/app/shell/shell_tabs.dart`, `lib/app/shell/app_shell.dart` (after P3-05)
- `lib/app/app_state.dart`: `courses`, `hasAnyActiveSession` (139), `progressView` (170),
  `goalHoursForCourse` (234), `todayTotalSeconds()` (884), `weekStart` (168)
- `lib/features/courses/course_format.dart` (`hoursPerCreditForLevel`) and the goal logic in
  `lib/features/courses/widgets/course_list.dart` (the weekly goal: custom hours, else
  credits times `hoursPerCreditForLevel(expLevel ?? 3)`)
- `lib/features/sessions/widgets/course_time_sheet.dart`: `_startTimer`, `_startStopwatch`,
  `_startPomodoro` and the `state.startTimer`, `state.startStopwatch`,
  `state.startPomodoro` calls in them
- `lib/features/habits/data/habit_service.dart:51-92` (`habitsStream`, local first),
  `lib/features/habits/models/habit.dart:431-500` (`isScheduledFor`,
  `isGoalMetForPeriod`), `lib/features/habits/screens/habits_screen.dart:270-286` (the
  filter used for "today")
- `lib/core/data/sync_service.dart:15, 36, 57` (`SyncStatus`, `status`, `lastError`)
- `lib/app/bootstrap.dart` (provider list)

## Context
- Line numbers are from `main` at `5a6359c`; later tasks moved code, so find it by name.
- After P3-06 Home holds `ShellHeader(title: StreakTitle(), actions: [SyncStatusChip()])`,
  `FirstRunCreditsGate`, `AutoFinishWatcher`, `ActiveSessionBar` and a bottom padding.
- `DESIGN.md` 3.5: the sync pill becomes one `meta` line under the header, only when offline
  or failing; hidden when up to date. `SyncService.status` is `offline`, `syncing` or
  `upToDate`; `lastError` is non-null after a failed sync.
- Today's studied time is `AppState.todayTotalSeconds()` (`app_state.dart:884`), the sum over
  every course including deleted ones. `app_state.dart` is in the size baseline and must not
  grow; this task does not edit it.
- "Goals are on" means `state.progressView != ProgressView.off` (the Settings option that
  shows goal bars on course rows). A course's daily goal is its weekly goal divided by 7,
  as the course row computes it.
- "Habits done today" uses the same rule as the Habits screen: a habit counts when
  `isScheduledFor(today)` and (it is done today or `!isGoalMetForPeriod(last7, today,
  mondayFirst: weekStart == WeekStart.monday)`); it is done when `(last7[dateKey] ?? 0) >=
  targetValue`, where `dateKey` is `yyyy-MM-dd` with zero padding.
- The last-used course is kept in `SharedPreferences` under `home_last_course_id_v1`,
  written when the time sheet successfully starts a timer, stopwatch or pomodoro. The id
  can point to a deleted course; Home then treats it as absent.
- Tab switching belongs to the shell. Home asks for it through callbacks.
- Strings (`DESIGN.md` 8.1 rules 11 and 12 for durations):

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `homeOffline` | No connection. Your changes are saved on this device. | Нет соединения. Изменения сохранены на устройстве. | Байланыс жоқ. Өзгерістер құрылғыда сақталды. |
  | `homeSyncFailed` | Could not sync. Your changes are saved on this device. | Не удалось синхронизировать. Изменения сохранены на устройстве. | Синхрондау мүмкін болмады. Өзгерістер құрылғыда сақталды. |
  | `homeGoalProgress(done, goal)` | Goal: {done} of {goal} | Цель: {done} из {goal} | Мақсат: {goal} ішінен {done} |
  | `habitsDoneSummary(done, total)` (int) | {done} of {total} done | {done} из {total} выполнено | {total} ішінен {done} орындалды |
  | `homeContinueCourse(course)` | Continue {course} | Продолжить: {course} | Жалғастыру: {course} |
  | `homeStartSession` | Start session | Начать сеанс | Сеансты бастау |
  | `durationHoursMinutes(hours, minutes)` (int) | {hours} h {minutes} min | {hours} ч {minutes} мин | {hours} сағ {minutes} мин |
  | `durationHours(hours)` (int) | {hours} h | {hours} ч | {hours} сағ |
  | `durationMinutes(minutes)` (int) | {minutes} min | {minutes} мин | {minutes} мин |

  Reuse `today`, `navStudy`, `habitsNavLabel`, `addCourse`, `selectCourse`. Placeholders
  of type `String` for `done`, `goal`, `course`; `int` where marked.

## Steps
1. (No `AppState` change.)
2. `lib/features/sessions/data/last_course_store.dart`: `class LastCourseStore extends
   ChangeNotifier` with `LastCourseStore(SharedPreferences prefs)`, `String? get id`, and
   `Future<void> save(String courseId)` (writes the key of the Context, notifies when the
   value changed). Export it from `sessions.dart`. In `bootstrap.dart` add
   `ChangeNotifierProvider<LastCourseStore>(create: (_) => LastCourseStore(prefs))`. In
   `course_time_sheet.dart`, after each of the three start calls that returns true (for the
   timer, read the return value that is ignored today), call
   `context.read<LastCourseStore>().save(widget.course.id)`.
3. `lib/features/habits/models/habit_day_summary.dart`: `({int done, int total})
   summarizeHabitsForDay(List<Habit> habits, DateTime day, {required bool mondayFirst})`
   implementing the rule of the Context. Export from `habits.dart`.
4. `lib/features/home/study_duration.dart`: `String formatStudyDuration(AppLocalizations
   l10n, int seconds)`: under an hour `durationMinutes`, whole hours `durationHours`,
   otherwise `durationHoursMinutes`. Minutes are rounded down.
5. `lib/features/home/home_goal.dart`: `int dailyGoalSeconds(AppState state)`: 0 when
   `progressView == ProgressView.off`; otherwise the sum over `state.courses` of
   `(weeklyHours * 3600 / 7).round()`, where `weeklyHours` is
   `state.goalHoursForCourse(c.id)` when positive, else `c.credits! *
   hoursPerCreditForLevel(c.expLevel ?? 3)` when `credits > 0`, else 0.
6. Shell wiring: in `shell_tabs.dart` add `enum ShellDestination { home, habits, study,
   groups, campus }`, a `destination` field on `ShellTab`, and a `required void
   Function(ShellDestination) onSelect` parameter of `buildShellTabs`; Home is built as
   `HomeScreen(onOpenStudy: () => onSelect(ShellDestination.study), onOpenHabits: () =>
   onSelect(ShellDestination.habits))`. `AppShell` passes a function that finds the index of
   that destination and calls `_onTabSelected`.
7. `HomeScreen({required VoidCallback onOpenStudy, required VoidCallback onOpenHabits})`, a
   `StatefulWidget` (it holds the habits stream), builds one `RefreshIndicator(onRefresh: () => context.read<SyncService>().syncNow())`
   around one `CustomScrollView`, top to bottom:
   - `ShellHeader(title: const StreakTitle())` with no other action. Delete
     `sync_status_chip.dart`.
   - The status line: when `sync.status == SyncStatus.offline`, `l10n.homeOffline`; else
     when `sync.lastError != null`, `l10n.homeSyncFailed`; else nothing. Shown as
     `Padding(horizontal: NumerSpace.lg, bottom: NumerSpace.sm, child: Text(..., style:
     context.text.meta))`.
   - `FirstRunCreditsGate`, `AutoFinishWatcher`, `ActiveSessionBar`, as today.
   - `NumerSection(title: l10n.today, child: Column(children: [block, button]))`:
     - the block: `NumerBlock(children: [studyRow, if (habits.total > 0) habitsRow])`.
       `studyRow` is `NumerRow(title: l10n.navStudy, value: formatStudyDuration(l10n,
       state.todayTotalSeconds()), subtitle: goal > 0 ? l10n.homeGoalProgress(
       formatStudyDuration(l10n, state.todayTotalSeconds()), formatStudyDuration(l10n, goal))
       : null, showChevron: true, onTap: onOpenStudy)` with `goal = dailyGoalSeconds(state)`.
       `habitsRow` is `NumerRow(title: l10n.habitsNavLabel, value:
       l10n.habitsDoneSummary(done, total), showChevron: true, onTap: onOpenHabits)`. The
       habits come from a `StreamBuilder` over `context.read<HabitService>().habitsStream(uid)`
       created once in `initState`, summarised with
       `summarizeHabitsForDay(habits, DateTime.now(), mondayFirst: ...)`; while the stream
       has no data the habits row is not shown.
     - the button, hidden when `state.hasAnyActiveSession`: `SizedBox(height:
       NumerSpace.md)` then, padded `NumerSpace.lg` left and right, a full-width
       `FilledButton`:
       - no courses: `l10n.addCourse`, opens `showAddCourseSheet(context)`;
       - `LastCourseStore.id` names an existing course: `l10n.homeContinueCourse(name)`
         (one line, ellipsis), opens `showCourseTimeSheet(context, course)`;
       - otherwise: `l10n.homeStartSession`, opens the course picker.
   - The bottom `SliverPadding` as today. Upcoming (P3-10) and News (P3-09) are added
     after the Today section by their tasks; add nothing for them now.
8. Course picker, `lib/features/home/course_picker_sheet.dart`: `Future<void>
   showCoursePickerSheet(BuildContext context)` with `showNumerSheet(title:
   l10n.selectCourse, builder: ...)` listing every course as `NumerRow(leading: <a 10 by 10
   circle filled with course.color>, title: course.name, onTap: ...)`; a tap pops the sheet
   and then calls `showCourseTimeSheet` with the root navigator's context. The 10 pt dot is
   the only place the course colour appears (`DESIGN.md` 2.1).
9. Strings: add the table's keys to the three ARB files with ICU placeholders; run
   `flutter gen-l10n`.
10. Tests:
    - `test/features/home/home_screen_test.dart` (replace the P3-06 file), with hand-written
      fakes for `AppState`, `SyncService` (`status`, `lastError`), `HabitService`
      (`habitsStream` returns a `StreamController` the test feeds), `AuthController`
      (`currentUser.uid`), a real `LastCourseStore` over
      `SharedPreferences.setMockInitialValues`, and a counting `ModuleSession` fake whose
      `idToken` increments a counter:
      - no courses: the button reads "Add course";
      - courses, no stored id: "Start session"; tapping opens a sheet listing the courses;
      - courses and a stored id of an existing course: "Continue <name>";
      - a stored id of a deleted course: "Start session";
      - a running session: no `FilledButton` in the Today section;
      - no habits scheduled today: no Habits row; two of three done: "2 of 3 done";
      - offline: the offline line shows; `upToDate` without error: no line; an error: the
        failed line;
      - goals off: the Study row has no subtitle; goals on with a credited course: it has
        the goal subtitle;
      - after pumping Home and pulling to refresh, the `ModuleSession` counter is 0 (provide
        the fake as `Provider<ModuleSession>` so a stray read would find it).
    - `test/features/habits/habit_day_summary_test.dart`: daily, specific days, a met period
      goal hidden unless done today, done counted at `targetValue`.
    - `test/features/home/study_duration_test.dart`: 0 s, 45 min, 1 h, 1 h 20 min in EN and RU.
    - `test/features/sessions/last_course_store_test.dart`: save then read; notifies once per
      change.
11. Run `dart run scripts/check_design.dart --write-baseline` if a count fell, and
    `./scripts/verify.sh`.
12. Screenshots (`DESIGN.md` 12): Home with no courses, with courses and no session, with a
    stored last course, with a running session, offline, and the course picker sheet; light
    and dark, EN and RU; KK for the Continue button with a long course name; one at text
    scale 1.3.

## Non-goals
- No feed, no Upcoming store (P3-09, P3-10). No module call of any kind from Home.
- Do not change the time sheet beyond the three `save` calls, nor the streak title.
- Do not change how studied time or habits are stored.

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
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (`docs/PRODUCT.md`: what Home shows).
- Home has exactly one `FilledButton` (`DESIGN.md` 1.4) and no `display` text.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The test files of step 10 exist and pass, including the zero-call module case.
- [ ] `grep -rn "SyncStatusChip" lib test` prints nothing.
- [ ] `grep -rn "FilledButton" lib/features/home/home_screen.dart` shows one construction site.
- [ ] Screenshots of step 12 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p3-07-home-today`, one commit, message `feat: rebuild home as the today screen` (subject line only). Do not push.
Report: files changed, test output, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- `habitsStream` reads Firestore before it emits the local list (then Home would make a
  network call on open; report what you found).
- A start call in the time sheet does not return whether it started.
