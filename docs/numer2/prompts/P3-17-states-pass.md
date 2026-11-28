# P3-17: States pass: confirm sheets and skeletons

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-12

## Goal
Finish the design pass (D-41): confirmations become `showNumerConfirm` sheets and the
centred spinners of list screens become `NumerSkeleton` with its 300 ms delay
(`DESIGN.md` 5.7, 6, 11).

## Read first
- `AGENTS.md`
- `docs/DESIGN.md` sections 5.4, 5.7, 6, 8, 11 and 12 (binding)
- `docs/numer2/DECISIONS.md` D-33, D-41
- `packages/numer_ui/lib/src/components/numer_confirm.dart`, `numer_skeleton.dart` (P3-01)
- `scripts/design_baseline.txt` (`alert` and `spinner` lines)

## Context
- Find sites with `grep -rn "AlertDialog(" lib` and `grep -rn "CircularProgressIndicator" lib`.
  Line numbers from earlier prompts are stale by now.
- A confirmation is an `AlertDialog` with a title, at most one sentence of content, and two
  actions (cancel and confirm). Only those become `showNumerConfirm`. A dialog that holds a
  text field, a list, a picker or more than one sentence stays an `AlertDialog` in this task
  and is listed in the report (for example the typed delete-account confirmation and the
  join-private-group code dialog). When unsure whether a dialog qualifies, leave it and list
  it in the report.
- `showNumerConfirm` returns `Future<bool>`; a destructive confirm (delete, remove, leave)
  uses `destructive: true`. Its confirm label is the existing action string of the dialog
  (`delete`, `remove`); "Cancel" comes from `MaterialLocalizations`.
- A list screen's loading state is a `Center(child: CircularProgressIndicator())` returned
  while a stream or future has no data. It becomes `NumerSkeleton()` (rows 3, two-line). A
  spinner inside a button becomes `NumerButtonChild(label: ..., loading: true)`. A spinner
  that blocks a whole screen during sign-in, export or deletion stays, and is listed in the
  report.

## Steps
1. Record the design totals as in P3-04 step 1.
2. For each confirmation `AlertDialog`: replace `await showDialog<bool>(... AlertDialog(title:
   Text(t), content: Text(b), actions: [...]))` with `await showNumerConfirm(context, title:
   t, body: b, confirmLabel: <the confirm action's string>, destructive: <true for delete,
   remove, leave>)`. Keep what the code does with the result.
3. For each list-loading spinner: return `const NumerSkeleton()` (inside a
   `SliverToBoxAdapter` where the parent is a sliver list).
4. For each spinner inside a button: `NumerButtonChild(label: <the button's label>, loading:
   <the existing busy flag>)`, with the button disabled while loading as today.
5. `dart run scripts/check_design.dart --write-baseline`; `alert` and `spinner` totals fall,
   none rises. Lower size baseline entries of shortened files.
6. Update `test/features/courses/course_list_test.dart` (P3-04): its delete cases find the
   confirm sheet's buttons instead of an `AlertDialog`. Tests: for two representative sites (the course delete confirmation in the course list,
   and the groups screen loading state), widget tests that the confirm sheet returns the
   same result as the dialog did, and that nothing shows for 299 ms and the skeleton after
   300 ms.
7. Run `./scripts/verify.sh`.
8. Screenshots before and after, light and dark, EN: every converted confirmation (one each)
   and two skeleton states; RU once.

## Non-goals
- Dialogs with inputs, permission rationales, blocking progress for sign-in, export or
  deletion; any wording change.

## Constraints
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/DESIGN.md` section 8. This task should need none; if a confirm action has no string, stop.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- UI: only the tokens and components of `docs/DESIGN.md`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. `scripts/check_file_size.sh` (in `verify.sh`) enforces it. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit; when it is split away, remove its entry. Never add a new path to the baseline.
- No unrequested features, abstractions, dependencies or error handling.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The `alert` and `spinner` totals are lower; the report lists every `AlertDialog(` and `CircularProgressIndicator` left, with the reason from the Context.
- [ ] The tests of step 6 pass.
- [ ] Screenshots of step 8 are attached; the report answers each review item of `DESIGN.md` section 11.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Review the screenshots.

## Deliverable
Branch `numer2/p3-17-states-pass`, one commit, message `refactor: use confirm sheets and skeletons` (subject line only). Do not push.
Report: files changed, design totals before and after, the list of what is left, test output, screenshots.

## Stop and ask if
- A confirmation's result is used in a way `Future<bool>` cannot carry (three outcomes).
