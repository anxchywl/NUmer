# P3-18: Focus mode in every input sheet

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-01, P3-15, P3-17, P1-05

## Goal
Owner rule: in every sheet or dialog that has a text field, while the keyboard is up only the
active field and one "Done" button stay on screen (`docs/numer2/DESIGN.md` 5.7, "Focus mode").
Apply it to every existing input sheet so the app behaves like the owner's other apps.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 5.5, 5.7 (Focus mode), 7.1
- `packages/numer_ui/lib/` the focus mode components (`NumerSheetFocusMode`, `NumerFocusFold`,
  `NumerFocusGap`, `NumerFocusActions`) and their tests, added in P3-01
- `/Users/anx/gradus/gradus_feature/lib/src/presentation/` the reference: `focus_mode.dart` and
  the sheets that use it (`course_form.dart`, `semester_form.dart`, `assignment_form.dart`)

## Context
- Behaviour: while `MediaQuery.viewInsets.bottom > 0` and a field has focus, every other part
  of the sheet folds (`NumerFocusFold`), gaps between fields fold (`NumerFocusGap`), and the
  actions become one primary button (`NumerFocusActions`): label "Done" (ARB key
  `focusDone`; add it if missing), or the form's submit label when the sheet has exactly one
  field. Done unfocuses, and the form returns.
- One `NumerSheetFocusMode` per sheet, created in the sheet's `State` and disposed with it;
  each field gets its node from `focusMode.nodeFor(<id>)`; keyboard "next" calls
  `focusMode.moveTo(<next id>)`.
- Sheets that already pin a primary button keep it when the keyboard is down.

## Steps
1. Inventory: `grep -rln "TextField\|TextFormField\|NumerCodeField" lib` and, for each file, decide
   whether the field sits in a sheet or dialog (`showModalBottomSheet`, `showNumerSheet`,
   `showDialog`, a widget named `*_sheet.dart` or `*Sheet`). Write the table (file, sheet,
   fields) into the report before changing code. Full-screen screens are out of scope.
2. For each sheet in the table, in one commit per sheet (or per two small sheets): add the
   focus mode, wrap every non-active part in `NumerFocusFold`, gaps in `NumerFocusGap`, and the
   actions in `NumerFocusActions`. Keep the sheet's behaviour otherwise identical.
3. For each sheet add a widget test: with a fake keyboard inset (`tester.view.viewInsets`),
   focusing field A hides field B and the title and shows Done; tapping Done restores them.
4. Screenshots for each sheet: keyboard down and keyboard up, light and dark, EN and RU.
5. Run `./scripts/verify.sh`.

## Non-goals
- Do not restyle sheets or change their fields, validation or copy beyond the Done label.
- Do not touch full-screen forms.
- Do not change `packages/numer_ui` behaviour; report a needed change instead.

## Constraints
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. This task should need none; if a confirm action has no string, stop.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. `scripts/check_file_size.sh` (in `verify.sh`) enforces it. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit; when it is split away, remove its entry. Never add a new path to the baseline.
- No unrequested features, abstractions, dependencies or error handling.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] The report's inventory table lists every sheet or dialog with a text field, each marked done.
- [ ] `grep` for `TextField`/`TextFormField` in sheets shows each one inside a sheet that uses `NumerSheetFocusMode`.
- [ ] One widget test per sheet as in step 3 passes.
- [ ] `./scripts/verify.sh` exits 0 (includes the 400-line size check).
- [ ] Screenshots attached as in step 4.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code.

## User actions
- Review the screenshots.

## Deliverable
Branch `numer2/p3-18-focus-mode`, small commits (one per sheet), message style
`feat: add focus mode to <sheet>`. Do not push.
Report: inventory table, files changed, test output, screenshots, anything not verified.

## Stop and ask if
- A sheet's layout cannot fold without changing its behaviour.
- The `numer_ui` focus mode components are missing or behave differently from Gradus.
