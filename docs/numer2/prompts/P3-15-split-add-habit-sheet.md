# P3-15: Split `add_habit_sheet.dart` (no behaviour change)

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-12

## Goal
Break the 2462-line `lib/features/habits/screens/add_habit_sheet.dart` into files under the
size limit (D-33) as far as its structure allows. Nothing a user can see or do changes.

## Read first
- `AGENTS.md` ("Repository Layout", "Size", "Comment style")
- `docs/numer2/DECISIONS.md` D-33
- `lib/features/habits/screens/add_habit_sheet.dart` (all of it), `lib/features/habits/habits.dart`
- `scripts/check_file_size.sh`, `scripts/file_size_baseline.txt`,
  `test/boundaries/allowlist.txt`, `scripts/design_baseline.txt`
- `prompts/P3-04-split-home.md` (the base-class and `part` mixin pattern)

## Context
- Line numbers are from `main` at `862c4c2`. If the file changed, find each piece by name.
- The file is one `StatefulWidget`, `AddHabitSheet` (15-24), and one state class (25-2462):
  fields (25-82), `initState`, `dispose`, `didChangeDependencies` (83-182), focus and step
  navigation (183-238), categories (239-310), a 1590-line `build` (311-1902) that shows one
  of four steps (`_screen == 0` at 338-837, `1` at 838-1193, `2` at 1194-1794, `3` from
  1795), then `_buildFreqOption`, `_buildPeriodTab`, `_buildPeriodToggle`,
  `_buildMonthDaySelector`, `_buildYearSelector`, `_buildHeader`, `_buildDaySelector`
  (1903-2213), `_submit` (2214-2326), `_saveNewCategory`, `_confirmDeleteCategory`
  (2327-2386), `_buildCourseSelector` (2387-2462).
- It imports `auth_service.dart` past the auth barrel (one allowlist line).
- This is a wizard with all its state in one object; the steps read and write that state.
  The split moves drawing code into widgets that get values and callbacks, and logic into a
  `part` mixin; the state object stays the only owner of the habit being built.

## Steps
1. Record the design totals as in P3-04 step 1.
2. Keep `AddHabitSheet` and its state at the current path. Split:
   - `abstract class _AddHabitSheetBase extends State<AddHabitSheet>` (with the mixins the
     state uses today) holds all fields; `_AddHabitSheetState extends _AddHabitSheetBase
     with _AddHabitActions` keeps the lifecycle methods and `build`.
   - `add_habit_actions.dart` (`part of`): `mixin _AddHabitActions on _AddHabitSheetBase`
     with step navigation, categories, `_submit`, `_saveNewCategory`,
     `_confirmDeleteCategory`.
   - Under `lib/features/habits/widgets/add_habit/`: one widget per step,
     `add_habit_name_step.dart` (`_screen == 0`), `add_habit_goal_step.dart` (`1`),
     `add_habit_schedule_step.dart` (`2`), `add_habit_extras_step.dart` (`3`), each taking
     the values it shows and callbacks for what it changes; and the builders 1903-2213 and
     2387-2462 as widgets (`frequency_option.dart`, `period_selector.dart` for the period tab
     and toggle, `month_day_selector.dart`, `year_selector.dart`, `add_habit_header.dart`,
     `day_selector.dart`, `course_selector.dart`). A step file that still passes 400 lines
     is split again by its visual parts (for example the icon grid, the colour row, the
     category list).
   - Where the old code called `setState` from inside a moved builder, the widget calls a
     callback and the state calls `setState`.
3. `build` assembles the header and the current step and stays under about 60 lines.
4. Imports go through barrels; remove the `add_habit_sheet.dart -> auth_service.dart` line
   from the allowlist if the file no longer imports it directly, and add no line.
5. `scripts/file_size_baseline.txt`: lower the entry to the new size of `add_habit_sheet.dart`,
   or remove it when the file is under 400; add no line.
6. `dart run scripts/check_design.dart --write-baseline`; no total rises.
7. Add `test/features/habits/add_habit_sheet_test.dart`: with fakes for `AuthController`
   (`currentUser` uid) and `HabitService` (`createHabit` records its argument), pump the
   sheet, type a name, go through the steps with the same taps a user makes, submit, and
   assert the recorded habit's name, type and frequency (characterisation of today's
   behaviour; write the test first, against the unsplit file, and keep it passing).
8. Run `./scripts/verify.sh`. Report `wc -l` of every new file and of the sheet.

## Non-goals
- No redesign, no string or duration change, no fixed bug (P3-12 replaces the chips). A bug
  you notice goes in the report.
- Do not touch `habit_schedule_editor.dart` or any other file of the feature beyond the barrel.

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
- [ ] Every new file is under 400 lines; `add_habit_sheet.dart` is under 400 or its baseline entry equals its new size, and the report says which and why.
- [ ] The characterisation test passes before and after the split (state both runs in the report).
- [ ] No design total rises; the size baseline gained no line.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Create one habit of each type on a device; edit one; the sheet behaves as before.

## Deliverable
Branch `numer2/p3-15-split-add-habit-sheet`, one commit, message `refactor: split the add habit sheet` (subject line only). Do not push.
Report: files with line counts, the design totals diff, test output, any bug noticed.

## Stop and ask if
- A step cannot be moved without a widget reaching into the state object.
- The characterisation test cannot drive the sheet without a real Firebase.
