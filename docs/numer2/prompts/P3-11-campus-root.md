# P3-11: Campus root

**Recommended model:** sonnet   **Effort:** medium
**Risk:** low   **Est.:** 2 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-05

## Goal
Finish the Campus root of `DESIGN.md` 4.4: one block of rows from the registry, with a search
field once there are more than eight, and the four states covered by tests.

## Read first
- `AGENTS.md`
- `docs/DESIGN.md` sections 3.4, 4.4, 5.2, 5.3, 5.5, 6, 8 and 12 (binding)
- `lib/features/campus/campus_screen.dart` (from P3-05), `lib/core/modules/module_descriptor.dart`,
  `lib/app/modules/` (from P3-03), `lib/app/shell/shell_tabs.dart`

## Context
- After P3-05, `CampusScreen({required List<ModuleDescriptor> modules, required void
  Function(ModuleDescriptor) onOpen})` shows `ShellHeader` and one `NumerBlock` of rows
  (leading icon, title, subtitle, chevron). The Campus tab exists only when at least one
  campus module is visible, so the screen never shows an empty list in the app; it still
  renders an empty block safely.
- Row order is the registry order (`DESIGN.md` 4.4). The screen does not sort.
- Strings: `campusSearchHint` Search / Поиск / Іздеу; `campusNoMatch` "No matches." /
  "Ничего не найдено." / "Ештеңе табылмады."; `campusClearSearch` (tooltip) Clear / Очистить /
  Тазалау.

## Steps
1. Make `CampusScreen` a `StatefulWidget`. When `modules.length > 8`, show above the block,
   padded `NumerSpace.lg` left and right and `NumerSpace.sm` below, a `TextField` (theme
   decoration, `hintText: l10n.campusSearchHint`, `prefixIcon: Icon(Icons.search)`, a
   suffix `IconButton(icon: Icon(Icons.close), tooltip: l10n.campusClearSearch)` while text
   is present). Filtering keeps modules whose localized title or subtitle contains the query,
   case-insensitive, in registry order. No match: `NumerEmptyState(message:
   l10n.campusNoMatch)` instead of the block. With eight or fewer modules there is no field.
2. With zero modules, render the header and nothing else (no empty block).
3. Strings: add the three keys to the three ARB files; run `flutter gen-l10n`.
4. Tests, `test/features/campus/campus_screen_test.dart` (fake `AppState` for the header):
   zero modules, no `NumerBlock` and no field; one module, one row with icon, title,
   subtitle, chevron, tapping calls `onOpen`, its builder is never called; nine modules,
   the field shows and typing a title filters to that row; a query that matches nothing
   shows "No matches."; clearing restores nine rows; eight modules, no field.
5. Run `./scripts/verify.sh`.
6. Screenshots (`DESIGN.md` 12): two fake modules and nine fake modules with a query, light
   and dark, EN and RU; one at text scale 1.3. Fake descriptors live only in a temporary
   uncommitted registry.

## Non-goals
- No real module, no change to the tab bar or the registry contract.

## Constraints
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- UI: only the tokens and components of `docs/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. `scripts/check_file_size.sh` (in `verify.sh`) enforces it. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit; when it is split away, remove its entry. Never add a new path to the baseline.
- No unrequested features, abstractions, dependencies or error handling.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The cases of step 4 exist and pass.
- [ ] Screenshots of step 6 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p3-11-campus-root`, one commit, message `feat: finish the campus root` (subject line only). Do not push.
Report: files changed, test output, screenshots, the section 11 answers.

## Stop and ask if
- `CampusScreen` from P3-05 has a different constructor than the Context states.
