# P1-03: `numer_ui`: tokens and the code field

**Recommended model:** sonnet   **Effort:** high
**Risk:** low   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-02, P0-12

## Goal
Start the shared UI package that NUmer and every module will use. This first slice holds the
design tokens, the six-box code field and the loading label for buttons, so the new auth
screens are built on the design language from the start.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 2, 5.4, 5.5, 7.1 and 11 (binding)
- `lib/app/app_theme.dart`
- `pubspec.yaml`, `scripts/verify.sh`, `scripts/check_design.dart`, `.github/workflows/ci.yml`

## Context
- The package lives at `packages/numer_ui/`, is named `numer_ui`, and has no dependency
  except `flutter`. Its SDK constraints are the same as the app's `pubspec.yaml`.
- NUmer's theme is `ColorScheme.fromSeed(seedColor: accent, brightness: ...)`. The five
  accent presets are `0xFF448AFF`, `0xFF10B981`, `0xFF7C3AED`, `0xFFFF7F50`, `0xFFF43F5E`.
- Token values and names are fixed by `DESIGN.md`. Copy them; never retune them.
- Inside `packages/numer_ui/lib/src/tokens/` literal colours, `TextStyle(` and numbers are
  allowed. A component file may declare private size constants at its top for dimensions
  that `DESIGN.md` gives for that component and that are not spacing tokens. Nothing else.
- `DESIGN.md` 5.5 wins over 2.5 for the code field: a box keeps its fill and gains a 2 px
  border when focused or in error.
- This task adds no screen. Its screenshots are images of the code field produced by a
  widget test.

## Steps
1. Create `packages/numer_ui/pubspec.yaml` (`name: numer_ui`, `publish_to: none`, the app's `environment` constraints, dependency `flutter`, dev dependencies `flutter_test` and `flutter_lints` at the version NUmer uses) and `analysis_options.yaml` including `package:flutter_lints/flutter.yaml`.
2. `lib/src/tokens/`:
   - `numer_space.dart`: `abstract final class NumerSpace` with `xs 4, sm 8, md 12, lg 16,
     xl 24, xxl 32, xxxl 48` as `static const double`.
   - `numer_radius.dart`: `NumerRadius` with `sm 8, md 12, lg 16, xl 20, full 999`.
   - `numer_motion.dart`: `NumerMotion` with `fast` 150 ms, `base` 200 ms, `slow` 250 ms,
     `enter = Curves.easeOutCubic`, `exit = Curves.easeInCubic`, and
     `static Duration of(BuildContext context, Duration token)` returning `Duration.zero` when
     `MediaQuery.disableAnimationsOf(context)` is true.
   - `numer_colors.dart`: `class NumerColors extends ThemeExtension<NumerColors>` with
     `success` and `warning`; constants `NumerColors.light` (`0xFF0F6B2E`, `0xFF8A4B00`) and
     `NumerColors.dark` (`0xFF81C995`, `0xFFFDD663`); `copyWith` and `lerp`.
   - `numer_text.dart`: `extension NumerTextContext on BuildContext { NumerText get text }`
     where `NumerText` exposes the getters `display`, `screenTitle`, `sectionTitle`,
     `rowTitle`, `body`, `meta`, each built from the Material text theme role, weight and
     colour role in the table of `DESIGN.md` 2.2, and the method
     `TextStyle status([Color? color])`, whose colour defaults to `onSurfaceVariant`.
     `display` adds `FontFeature.tabularFigures()`.
3. `lib/src/components/numer_otp_field.dart`: `NumerOtpField` as `DESIGN.md` 5.5: parameters
   `length` (default 6), `onCompleted(String)`, `onChanged(String)?`, `enabled`, `hasError`,
   `semanticsLabel`, `controller?`, `focusNode?`, `autofocus`.
   - Private constants at the top of the file: `_boxWidth = 48`, `_boxHeight = 56`,
     `_borderWidth = 2`.
   - Layout: a centred row of `length` boxes with `NumerSpace.sm` between them; each box is
     flexible with a maximum width of `_boxWidth`, so the row shrinks on a 320 pt screen.
   - The text field sits in a `Stack` under the boxes with `Positioned.fill`: text colour and
     cursor colour `Colors.transparent`, `showCursor: false`, `enableInteractiveSelection:
     false`, a decoration with `InputBorder.none` and an empty counter,
     `autofillHints: [AutofillHints.oneTimeCode]`, `keyboardType: TextInputType.number`,
     `FilteringTextInputFormatter.digitsOnly` and a length limit. Do not use `Opacity`,
     `Offstage` or `Visibility`.
   - The widget also listens to its controller and, on every change, reduces the text to its
     first `length` digits. This makes a value set programmatically (and a paste) behave like
     typing.
   - `onChanged` fires on every change of the sanitised value. `onCompleted` fires once each
     time the value reaches `length` digits.
   - When `hasError` becomes true the field clears and requests focus.
   - Tapping any box focuses the field. The whole control is one semantics node with the label
     and the current value.
4. `lib/src/components/numer_button_child.dart`: `NumerButtonChild({required String label,
   bool loading = false})`: when not loading, the label text; when loading, a row sized to its
   content with a 16 by 16 `CircularProgressIndicator` (stroke width 2, colour from the
   ambient `IconTheme` or `DefaultTextStyle`), `NumerSpace.sm`, and the label. This is the only
   file outside the tokens that may contain `CircularProgressIndicator`.
5. `lib/numer_ui.dart` exports the five token files and the two components.
6. Tests in `packages/numer_ui/test/`:
   - `tokens_test.dart`: every `NumerSpace` and `NumerRadius` value except `full` is a multiple
     of 4; the three durations are 150, 200, 250 ms; `NumerMotion.of` returns zero under
     `MediaQueryData(disableAnimations: true)`; with a default `ThemeData(useMaterial3: true)`
     the seven text styles have sizes 45, 22, 16, 16, 14, 12, 12 and weights 400, 700, 700,
     400, 400, 400, 500.
   - `contrast_test.dart`: for each of the five presets and both brightnesses, compute WCAG
     contrast ratios and assert `onSurface` and `onSurfaceVariant` on `surface` and on
     `surfaceContainerHighest` are at least 4.5; `primary` on `surface` at least 3.0; `error`
     on both surfaces at least 4.5; `NumerColors` `success` and `warning` (light on light
     schemes, dark on dark) on both surfaces at least 4.5.
   - `numer_otp_field_test.dart`: typing six digits calls `onCompleted` once with them; typing
     a letter is ignored; setting the controller text to `123456` fills six boxes and calls
     `onCompleted` once; setting it to `12345678` leaves `123456`; `hasError: true` clears the
     field; the semantics label is present; the field reports `AutofillHints.oneTimeCode`; at
     a width of 320 the row does not overflow.
   - `numer_button_child_test.dart`: the label is present in both states; the spinner only
     when loading.
   - `otp_images_test.dart`: writes images of the field (empty, partly filled, focused, error;
     light and dark; text scale 1.0 and 1.3) with `matchesGoldenFile`. Generate them with
     `--update-goldens`, attach them to the report, and do not commit them (add their folder
     to `.gitignore`); tag the test so the normal test run skips it.
7. In NUmer's `pubspec.yaml` add `numer_ui: {path: packages/numer_ui}`. In `lib/app/app_theme.dart` add the extension to the theme: `extensions: [brightness == Brightness.dark ? NumerColors.dark : NumerColors.light]`. Change nothing else in the theme.
8. In `scripts/verify.sh`, after the app's own steps, add for `packages/numer_ui`: `flutter pub get`, `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, `flutter test`. Add the same four commands as a step of the `flutter` job in `.github/workflows/ci.yml`.
9. In `scripts/check_design.dart`, skip `packages/numer_ui/lib/src/tokens/` for the `color_literal` and `text_literal` patterns, and skip `packages/numer_ui/lib/src/components/numer_button_child.dart` for the `spinner` pattern. Run `dart run scripts/check_design.dart --write-baseline`; the diff of `scripts/design_baseline.txt` must contain no line for a file under `packages/numer_ui` with a count above 0, except the transparent-colour uses in the code field if the script counts them (then extend the skip to that one pattern and file, and say so). Run `./scripts/verify.sh`.

## Non-goals
- Do not add `NumerTheme`, rows, sheets or any other component (P3-01).
- Do not change any existing screen.
- Do not add a font, an icon package or any dependency.
- Do not change a token value to make a test pass; if the contrast test fails, stop.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `cd packages/numer_ui && flutter analyze && flutter test` exits 0.
- [ ] `./scripts/verify.sh` exits 0 and now runs the package steps.
- [ ] `grep -rn "fontFamily" packages/numer_ui` prints nothing.
- [ ] `grep -rn "package:numer_app" packages/numer_ui` prints nothing.
- [ ] `grep -rln "CircularProgressIndicator" packages/numer_ui/lib` prints only `numer_button_child.dart`.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p1-03-numer-ui-tokens`, one commit, message `feat: add numer_ui tokens, code field and button loading label` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- A preset fails a contrast assertion.
- `MediaQuery.disableAnimationsOf` does not exist in this Flutter version.
- The hidden text field does not receive input or autofill in a widget test with the recipe above (report what you observed).
