# P3-16: Split `habits_screen.dart` (no behaviour change)

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-12

## Goal
Break the 1610-line `lib/features/habits/screens/habits_screen.dart` into files under the
size limit (D-33), before P3-05 changes its header and P3-12 removes its glass pill. Nothing
a user can see or do changes.

## Read first
- `AGENTS.md` ("Repository Layout", "Size", "Comment style")
- `docs/numer2/DECISIONS.md` D-33
- `lib/features/habits/screens/habits_screen.dart` (all of it), `lib/features/habits/habits.dart`
- `scripts/check_file_size.sh`, `scripts/file_size_baseline.txt`,
  `test/boundaries/allowlist.txt`, `scripts/design_baseline.txt`
- `prompts/P3-04-split-home.md` (the base-class and `part` mixin pattern)

## Context
- Line numbers are from `main` at `862c4c2`. If the file changed, find each piece by name.
- What the file holds:

  | Lines | Piece |
  |---|---|
  | 23-29 | `HabitsScreen` |
  | 30-168 | `_HabitsScreenState`: fields, `initState`, date helpers (75-122), iOS clearances (128-155), `_showAddHabitSheet` |
  | 169-625 | `build`: header with the Progress and List switch (196-240), the progress tab (252-, Eisenhower matrix or the today list), the list tab |
  | 626-661 | `_toggleHabit` |
  | 662-710 | `_buildTabItem` (the switch; P3-05 replaces it) |
  | 711-800 | `_buildHorizontalDatePicker` |
  | 801-921 | `_buildTodayHabitItem`, `_formatDurationHms`, `_dateKey` |
  | 927-1002 | `_IosLiquidActionPill` (P3-12 removes it) |
  | 1003-1610 | `_HabitItem` and its state (a row of the list tab with a week strip) |

- It imports `auth_service.dart` past the auth barrel (one allowlist line).

## Steps
1. Record the design totals as in P3-04 step 1.
2. Keep `HabitsScreen` and its state at the current path. Move:
   - `lib/features/habits/widgets/habit_list_item.dart`: `_HabitItem` as `HabitListItem`;
     if it passes 400 lines, its week strip and its frequency text helpers
     (`_getFrequencyText`, `_periodLabel`, `_weekdayLabel`, `_formatWeekRange`) go to
     `habit_week_strip.dart` and `habit_frequency_text.dart`.
   - `lib/features/habits/widgets/habits_date_picker.dart`: `_buildHorizontalDatePicker` as
     `HabitsDatePicker` with the dates, the selected date, the scroll controller and an
     `onSelect` callback.
   - `lib/features/habits/widgets/today_habit_item.dart`: `_buildTodayHabitItem` and
     `_formatDurationHms`, as `TodayHabitItem` with an `onToggle` callback.
   - `lib/features/habits/widgets/habits_progress_tab.dart` and `habits_list_tab.dart`: the
     two tab bodies of `build`, as sliver-returning widgets taking the stream, the selected
     date and callbacks.
   - `lib/features/habits/widgets/ios_liquid_action_pill.dart`: the pill unchanged (P3-12
     deletes the file), so the screen file loses it.
   - The date helpers and `_dateKey` (two identical copies at 922 and 1178; diff them first)
     to `lib/features/habits/habit_dates.dart` as top-level functions.
   - If the state still passes 400 lines, apply P3-04's pattern (base class with the fields,
     `part` mixin with `_toggleHabit`, `_scrollToToday`, `_updateWeekDates`).
3. `build` keeps the `Scaffold`, the scroll listener, the header and the switch, and
   assembles the tabs; under about 60 lines if the header allows, else name it in the report.
4. Imports through barrels; remove the `habits_screen.dart -> auth_service.dart` allowlist
   line if the file no longer imports it directly; add none.
5. `scripts/file_size_baseline.txt`: lower or remove the `habits_screen.dart` entry; add no
   line. `dart run scripts/check_design.dart --write-baseline`; no total rises.
6. Add `test/features/habits/habit_dates_test.dart` (characterisation of the moved helpers:
   `dateKey`, the week-start offset for Monday and Sunday starts, future-date check).
7. Run `./scripts/verify.sh`. Report `wc -l` of every new file and of the screen.

## Non-goals
- Do not replace the switch, the pill or any chip (P3-05, P3-12). No string or duration
  change, no fixed bug.

## Constraints
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`; this task adds none.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji. Existing comments move with their code unchanged.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. `scripts/check_file_size.sh` (in `verify.sh`) enforces it. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit; when it is split away, remove its entry. Never add a new path to the baseline.
- No unrequested features, abstractions, dependencies or error handling.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0, including the boundary, design and size checks.
- [ ] Every new file is under 400 lines; `habits_screen.dart` is under 400 or its baseline entry equals its new size, and the report says which.
- [ ] No design total rises; the size baseline gained no line.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- On a device: check a habit, switch Progress and List, scroll the date strip, open the
  calendar and archive screens. Everything works as before.

## Deliverable
Branch `numer2/p3-16-split-habits-screen`, one commit, message `refactor: split the habits screen` (subject line only). Do not push.
Report: files with line counts, the design totals diff, test output, any bug noticed.

## Stop and ask if
- The two `_dateKey` copies or the two `_weekStartOffset` copies differ.
- A tab body cannot move without reaching into the state object.
