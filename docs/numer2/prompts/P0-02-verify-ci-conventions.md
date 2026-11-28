# P0-02: Verify script, CI and conventions

**Recommended model:** sonnet   **Effort:** high
**Risk:** low   **Est.:** 4 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** none

## Goal
Give the repo one command that proves a change is acceptable, a CI workflow that runs it,
and an `AGENTS.md` that states the code conventions every later NUmer 2.0 prompt relies on.
Nothing enforces anything today: there is no `scripts/` directory and no `.github/` directory.

## Read first
- `AGENTS.md`, `README.md` lines 55-90, `analysis_options.yaml`, `l10n.yaml`
- `docs/DESIGN.md` sections 8.3 and 11 (the two mechanical checks you implement)
- `docs/numer2/DECISIONS.md` section F (the conventions you copy into `AGENTS.md`)
- `test/smoke/app_boot_test.dart`, `test/features/account/accent_color_picker_test.dart`
- `functions/package.json`

## Context
- Flutter 3.38.5, Dart 3.10.4. `flutter analyze` uses `flutter_lints` only.
- Tests today: 2 files; one test is `skip: true`.
- ARB key counts: EN 397, RU 382, KK 396. RU and KK are missing keys.
- Known layer violations that the boundary test must record, not fix:
  `lib/core/data/storage.dart:10-13` imports four features;
  `lib/shared/widgets/universal_avatar.dart:7` imports a feature; about 49 imports reach into
  a feature without going through its barrel (`lib/main.dart:20-37` and 34 others).
- The dependency direction is `features -> core -> shared`. `lib/app/` and `lib/main.dart`
  are the composition root and may import anything, but only through barrels.
- Functions build with `npm run build` (`tsc`). There are no functions tests yet.

## Steps
1. Run `flutter pub get`, `flutter gen-l10n`, `flutter analyze` and `flutter test`. Save the output for the report. If analyze or test fails, stop (see "Stop and ask").
2. Commit A, formatting only: run `dart format lib test` and commit the result as `chore: format lib and test`. This commit contains nothing else.
3. Add the missing ARB keys so the three files have identical key sets (ignore keys starting
   with `@`). Translate naturally, reusing terms already present in that file. List every added
   key and its text in the report.
4. Create `scripts/check_arb.dart` (run with `dart run scripts/check_arb.dart [dir]`, default
   `lib/l10n`): load `app_en.arb`, `app_ru.arb`, `app_kk.arb`, compare the sets of keys not
   starting with `@`, print each missing key with its file, exit 1 on any difference.
5. Create `scripts/check_copy.dart` and the wrapper `scripts/check_copy.sh`
   (`dart run scripts/check_copy.dart "$@"`). For every value of every non-`@` key in the three
   ARB files, report a violation when the value contains:
   - U+2014, U+2013, U+00B7, U+2022, or `#`;
   - `!`;
   - in `app_en.arb` only, case-insensitive whole words: unlock, supercharge, seamless,
     elevate, journey, effortless, magic, powerful, awesome, oops, whoops, or the phrase
     `dive in`.
   A violation is identified as `<file>:<key>:<rule>`. Violations listed in
   `scripts/copy_allow.txt` are ignored. `--write-baseline` rewrites that file from the current
   violations. The script exits 1 on a violation not in the file, and also on a line in the
   file that no longer violates (so the list can only shrink). Run `--write-baseline` once.
6. Create `scripts/check_design.dart` and the wrapper `scripts/check_design.sh`. It counts, per
   Dart file under `lib/` (excluding `lib/l10n/`) and under `packages/` if that directory
   exists, the matches of each pattern below, and compares with `scripts/design_baseline.txt`
   (lines `id<TAB>path<TAB>count`). Exit 1 when a count is higher than the baseline or a file
   not in the baseline has a count above 0. `--write-baseline` rewrites the file. Run it once.

   | id | regex |
   |---|---|
   | gradient | `\b(Linear|Radial|Sweep)Gradient\b` |
   | blur | `\bBackdropFilter\b|ImageFilter\.blur` |
   | shadow | `\bBoxShadow\(|elevation:\s*[1-9]` |
   | chip | `\b(Choice|Filter|Input|Action)?Chip\(|\bBadge\(` |
   | color_literal | `\bColors\.(?!transparent\b)\w+|\bColor\(0x` |
   | text_literal | `\bTextStyle\(|\bfontSize:|\bfontFamily:|\bGoogleFonts\b` |
   | weight | `FontWeight\.w(600|800|900)` |
   | spinner | `\bCircularProgressIndicator\b` |
   | snackbar | `\bSnackBar\(` |
   | alert | `\bAlertDialog\(` |
   | button | `\b(Outlined|Elevated)Button\b` |
   | icon_pack | `\b(MdiIcons|PhosphorIcons|FontAwesomeIcons|LucideIcons|SimpleIcons)\b` |
   | opacity | `\.withOpacity\(|\bOpacity\(` |
   | print | `\bdebugPrint\(|\bprint\(` |
7. Create `scripts/coverage_floor.sh <lcov file> <floor percent>`: sum `LF` and `LH` over all
   records whose `SF` path does not start with `lib/l10n/`, print the percentage with one
   decimal, exit 1 when it is below the floor. Run `flutter test --coverage`, take the printed
   percentage, round it down to a whole number and write that number to
   `scripts/coverage_floor.txt`.
8. Create `test/boundaries/layer_boundaries_test.dart` and `test/boundaries/allowlist.txt`.
   The test reads every `.dart` file under `lib/` (excluding `lib/l10n/`), resolves each
   `import` of `package:numer_app/...` or a relative path to a path under `lib/`, and reports a
   violation `<importer> -> <imported>` when:
   - a file under `lib/shared/` imports anything under `lib/core/`, `lib/features/` or `lib/app/`;
   - a file under `lib/core/` imports anything under `lib/features/` or `lib/app/`;
   - a file under `lib/features/<a>/` imports a file under `lib/features/<b>/` (b differs from
     a) other than `lib/features/<b>/<b>.dart`;
   - a file under `lib/app/` or `lib/main.dart` imports a file under `lib/features/<b>/` other
     than `lib/features/<b>/<b>.dart`;
   - a file under `lib/features/` imports anything under `lib/app/` except
     `lib/app/app_state.dart`.
   The test fails when a violation is not in `allowlist.txt`, and also when a line of
   `allowlist.txt` is no longer a violation. Fill `allowlist.txt` with today's violations,
   sorted.
9. Create `scripts/verify.sh` (`#!/usr/bin/env bash`, `set -euo pipefail`, run from the repo
   root). Its header comment lists what it does not run: device builds, emulator tests,
   deploys. Steps in order:
   `flutter pub get`; `flutter gen-l10n`;
   `dart format --output=none --set-exit-if-changed lib test`; `flutter analyze`;
   `dart run scripts/check_arb.dart`; `bash scripts/check_copy.sh`; `bash scripts/check_design.sh`;
   `flutter test --coverage`;
   `bash scripts/coverage_floor.sh coverage/lcov.info "$(cat scripts/coverage_floor.txt)"`;
   `(cd functions && npm ci && npm run build)`.
   Make it executable.
10. Create `.github/workflows/ci.yml`: triggers `push` to `main` and `pull_request`;
   `permissions: contents: read`; job `flutter` on `ubuntu-latest` with Flutter 3.38.5 (stable)
   running `./scripts/verify.sh`; Node 20 set up in the same job for the functions step. Pin
   each third-party action to a full commit SHA with the version in a trailing comment. No
   secrets, no device build, no deploy.
11. In `AGENTS.md`, after the section "Core Development Rules for Agents", add two sections:
   - `## Verify before reporting`: run `./scripts/verify.sh`; report its real output; a task is
     not done until it passes; list what the script does not run.
   - `## Code conventions`: the table of `docs/numer2/DECISIONS.md` section F, rows Comments,
     Language, Commits, Shape, Leftovers, Errors, Scope, Tests, Coverage, Docs, copied as a
     bullet list.
   Change nothing else in `AGENTS.md`.
12. Update `README.md` lines 75-79 to say `./scripts/verify.sh` must pass. Commit B: `chore: add verify script, ci and conventions`.

## Non-goals
- Do not fix any layer violation, design violation or copy violation; record them in the baselines.
- Do not change `analysis_options.yaml`.
- Do not un-skip or rewrite the skipped test.
- Do not rewrite the rest of `AGENTS.md` or `README.md` (that is P0-16).
- Do not add a build or deploy job to CI.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- The scripts are Dart or bash only. No new package in `pubspec.yaml`.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0 on a clean checkout of the branch.
- [ ] `dart run scripts/check_arb.dart` exits 0.
- [ ] Adding `import 'package:numer_app/features/habits/data/habit_service.dart';` to `lib/shared/widgets/app_toast.dart` makes `flutter test test/boundaries` fail; removing it makes it pass (do this, then revert, and say so in the report).
- [ ] Adding one `Color(0xFF000000)` to `lib/features/history/screens/history.dart` makes `bash scripts/check_design.sh` exit 1 (do this, then revert).
- [ ] `git log --oneline main..HEAD` shows exactly two commits, the first touching only formatting.
- [ ] The report lists every ARB key added with its RU or KK text.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Review the added RU and KK strings (`docs/numer2/USER_ACTIONS.md` B-1).

## Deliverable
Branch `numer2/p0-02-verify-ci-conventions`. Two commits, in this order: `chore: format lib and test` (formatting only), then `chore: add verify script, ci and conventions`. Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- `flutter analyze` or `flutter test` fails before any change.
- The format commit changes generated files that `flutter gen-l10n` then changes back.
- A missing ARB key has no clear meaning from the EN text and its usage.
