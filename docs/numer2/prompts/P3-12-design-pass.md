# P3-12: Design pass: glass, gradients, chips, raw toasts

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-05, P3-14, P3-15

## Goal
Remove from existing screens the patterns `DESIGN.md` section 11 bans that a token or a
`numer_ui` component replaces one for one: the last glass pill, the auth gradient, mode
chips, hand-built segmented pills, raw snack bars, a card shadow, the Kazakh font-size
branches and one hard-coded string. Screens are not redesigned. Confirmation dialogs and
loading spinners are P3-17 (D-41).

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 1.2, 2, 5.4, 5.5, 5.6, 5.9, 7.2, 8, 11 and 12 (binding)
- `docs/numer2/DECISIONS.md` D-29, D-31, D-33, D-41
- `scripts/check_design.dart`, `scripts/design_baseline.txt`, `scripts/file_size_baseline.txt`
- `packages/numer_ui/lib/numer_ui.dart` (`NumerFab`, `showNumerMessage`)
- Each file named in the steps, found with the grep given there

## Context
- Line numbers in this prompt are from `main` at `862c4c2`, before P3-05, P3-14 to P3-16
  moved code. Locate every site with the grep in its step; never trust a line number alone.
- Already done by earlier tasks, not repeated here: the Home glass pills and the AI sparkle
  (P3-06), the Habits Progress and List switch (P3-05). P3-16 moved the Habits glass pill to
  `lib/features/habits/widgets/ios_liquid_action_pill.dart`.
- Out of scope, left for P3-17 or later and listed in the report: `AlertDialog`,
  `CircularProgressIndicator`, `FilterChip` multi-selects (weekday pickers, colour and
  category filters) whose replacement is not one for one, `Colors.*` literals, `TextStyle(`
  literals other than the ones named here.
- `DESIGN.md` 5.6: the floating action is `FloatingActionButton.extended`, bottom right,
  identical on both platforms, hides on scroll down. `NumerFab` takes `visible`.
- `DESIGN.md` 7.2: a segmented control gives `HapticFeedback.selectionClick()` on change.
- New string: `habitsAddHabit` Add habit / Добавить привычку / Әдет қосу.

## Steps
1. Record the design totals as in P3-04 step 1 (into `/tmp/design_before.txt`).
2. Habits floating action. `grep -rn "IosLiquidActionPill\|_createNewLabel\|floatingActionButtonLocation" lib/features/habits`.
   In the Habits screen replace both branches (the iOS pill and the Android
   `FloatingActionButton`) with one `NumerFab(icon: Icons.add, label: l10n.habitsAddHabit,
   onPressed: _showAddHabitSheet, visible: _fabVisible)`; keep the iOS bottom lift padding
   so it clears the floating tab bar; remove `floatingActionButtonLocation:
   FloatingActionButtonLocation.startFloat` so it sits bottom right. Delete
   `ios_liquid_action_pill.dart`. Replace `_createNewLabel` at its other use (the empty
   state button) with `l10n.habitsAddHabit` and delete the constant.
3. Auth gradient. `grep -rn "Gradient" lib/features/auth`. Replace the decorative
   `LinearGradient` background (`auth_screen.dart:78` today) with the flat
   `colorScheme.surface` of the same container (`color:` instead of `gradient:`). Other
   sessions changed the auth screens in phase 1; edit only the gradient.
4. Mode chips to `SegmentedButton` (`DESIGN.md` 5.5: 2 to 4 modes):
   - Habit type in the add habit sheet (`grep -rn "ChoiceChip" lib/features/habits`): the
     three `ChoiceChip`s for yes/no, numeric and time become one
     `SegmentedButton<HabitType>` with the same labels and the same `onSelected` logic.
   - Statistics range: `_SegChip` (week, month, year; `grep -rn "SegChip" lib/features/stats`)
     becomes a `SegmentedButton` over the range enum; delete `_SegChip`.
   - Statistics report format (`exportFormatCSV`, `exportFormatExcel` `ChoiceChip`s in the
     habit report sheet): a two-segment `SegmentedButton<String>`.
   Each gets `showSelectedIcon: false` and calls `HapticFeedback.selectionClick()` on
   change. Remove the chip colour and label style overrides that came with them.
5. Leaderboard period selector. `grep -rn "_PeriodSelector" lib/features/groups`: its
   `Container` of `GestureDetector` pills becomes `SegmentedButton<StatisticsPeriod>` with
   one segment per `StatisticsPeriod.values`, the same labels, padded `NumerSpace.lg` left and
   right, and the haptic.
6. Raw snack bars. `grep -rn "SnackBar(" lib`. Replace each `ScaffoldMessenger.of(context).showSnackBar(SnackBar(
   content: Text(x)))` with `showAppMessage(context, x)`; one that reports a failure (red
   background, an error string, or inside a `catch`) gets `isError: true`; a `SnackBarAction`
   becomes `actionLabel` and `onAction`. Where the code captured a `ScaffoldMessenger` before
   an `await`, capture nothing and check `if (!context.mounted) return;` before the call
   instead. Keep every message text as it is.
7. Statistics section card shadow. `grep -rn "BoxShadow" lib/features/stats`: delete the
   `boxShadow` of the section container (P3-14 moved it to
   `widgets/stats_section_container.dart`). Keep its fill and radius.
8. Kazakh font branches. `grep -rn "== 'kk'" lib/features/stats`: delete each `isKK`
   variable and the `fontSize: isKK ? ... : null` it feeds; the label keeps `maxLines: 2`
   and gets `overflow: TextOverflow.ellipsis` (`DESIGN.md` 2.2: wrap, then ellipsize).
9. Strings: add `habitsAddHabit`; run `flutter gen-l10n`.
10. `dart run scripts/check_design.dart --write-baseline`; compute the totals into
    `/tmp/design_after.txt`; every total is equal or lower, and `gradient`, `blur`, `chip`,
    `snackbar` and `shadow` are lower. Lower the size baseline entries of any baseline file
    you shortened.
11. Tests: extend or add widget tests that find a `SegmentedButton` (and no `ChoiceChip`)
    for the habit type, the statistics range and the leaderboard period, and that selecting
    a segment calls the same callback as before; the Habits screen has one
    `FloatingActionButton` labelled "Add habit".
12. Run `./scripts/verify.sh`.
13. Screenshots, before and after, light and dark, EN: Habits (with the action), the add
    habit type step, Statistics (range control and a section card), the habit report sheet,
    the group leaderboard, the sign-in screen, one toast; Statistics in KK at text scale 1.3.

## Non-goals
- No redesign of any screen, no new component, no behaviour change apart from the controls
  being the Material ones.
- Do not touch `AlertDialog`, spinners, `FilterChip` multi-selects, the avatar catalogue,
  the colour picker's hue gradient or the iOS tab bar.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. `scripts/check_file_size.sh` (in `verify.sh`) enforces it. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit; when it is split away, remove its entry. Never add a new path to the baseline.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] `grep -rn "IosLiquidActionPill\|_createNewLabel\|_SegChip\|== 'kk'" lib` prints nothing.
- [ ] `grep -rn "SnackBar(" lib` prints nothing; `grep -rn "Gradient" lib` lists only the colour picker and the iOS tab bar.
- [ ] `grep -rn "ChoiceChip" lib` prints nothing.
- [ ] The design totals diff (before and after per pattern) is in the report; no total rose.
- [ ] Before and after screenshots of step 13 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] The report lists the banned patterns left in place and which later task owns each.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Review the before and after screenshots (`USER_ACTIONS.md` E-4).

## Deliverable
Branch `numer2/p3-12-design-pass`, one commit, message `refactor: replace banned patterns with design components` (subject line only). Do not push.
Report: files changed, design totals before and after, test output, screenshots, the section 11 answers, the list of what is left.

## Stop and ask if
- A replaced control carried meaning a `SegmentedButton` or a toast cannot express (for
  example a chip that also showed a count).
- A snack bar is shown from code with no `BuildContext` to pass to `showAppMessage`.
