# P3-01: `numer_ui`: theme builder and components

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 8 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P1-03

## Goal
Give `packages/numer_ui` the theme builder and every component of `DESIGN.md` section 5, so
the shell tasks (P3-03 to P3-11) and the modules build screens from one kit instead of
hand-styled widgets.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 1, 2, 3.2, 3.3, 5, 6, 7.1, 11 and 12 (binding)
- `packages/numer_ui/lib/numer_ui.dart` and everything under `packages/numer_ui/lib/src/`
- `packages/numer_ui/test/` (all five files; `otp_images_test.dart` is the pattern for images)
- `lib/app/app_theme.dart` (40 lines), `lib/shared/widgets/app_toast.dart` (44 lines)
- `scripts/check_design.dart` (98 lines), `scripts/design_baseline.txt`

## Context
- Line numbers below are from `main` at `5a6359c`. If a file has moved on, find the code by
  the names given.
- Today's theme is `buildAppTheme(Color accent, Brightness brightness)` in
  `lib/app/app_theme.dart:17-40`: Material 3, `ColorScheme.fromSeed(seedColor: accent,
  brightness: brightness)`, the `NumerColors` extension, and a `switchTheme` whose selected
  thumb is `accent` and selected track `accent.withValues(alpha: 0.5)`. Nothing else is
  customised. `lightFallbackTheme` and `darkFallbackTheme` (lines 4-15) are for the bootstrap
  loading screen and stay as they are.
- `buildAppTheme` is called from `lib/app/numer_app.dart:105-106`.
- `showAppMessage` (`lib/shared/widgets/app_toast.dart:4-44`) is the toast. It is called 58
  times from 13 files; those call sites do not change in this task.
- `numer_ui` depends on `flutter` only and has no localisations. A component that needs a
  word the package cannot know takes it as a parameter, except "Cancel", which comes from
  `MaterialLocalizations.of(context).cancelButtonLabel`.
- `scripts/check_design.dart` counts banned patterns per file under `lib/` and `packages/`
  (including `packages/numer_ui/test/`) and fails when a count rises above
  `scripts/design_baseline.txt`. Its `_exempt` map (lines 9-13) skips one path prefix per
  pattern id.
- The toast is the one component allowed a `SnackBar(` and a shadow (`DESIGN.md` 2.5, 11).
- `DESIGN.md` 12 asks for screenshots. This task adds no screen, so the screenshots are
  images of a component gallery produced by a tagged widget test, as P1-03 did for the code
  field. There is no `example/` app.
- A component file may declare private constants at its top for dimensions that
  `DESIGN.md` states for that component and that are not tokens (row heights 56 and 72,
  avatar size 32, divider thickness 1, skeleton line heights 16 and 12, the 300 ms delay).
  No other literal number.

## Steps
1. `packages/numer_ui/lib/src/theme/numer_theme.dart`: `abstract final class NumerTheme`
   with `static ThemeData build({required Color seed, required Brightness brightness})`.
   Build `final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)` and
   `final base = ThemeData(useMaterial3: true, colorScheme: scheme)`, then return
   `base.copyWith(...)` with exactly these properties:
   - `extensions`: `[brightness == Brightness.dark ? NumerColors.dark : NumerColors.light]`.
   - `switchTheme`: copied unchanged from `lib/app/app_theme.dart:27-38`, with `accent`
     renamed `seed`.
   - `appBarTheme`: `AppBarTheme(centerTitle: false, backgroundColor: scheme.surface,
     surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0,
     titleTextStyle: base.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w700,
     color: scheme.primary))`.
   - `inputDecorationTheme`: `filled: true`, `fillColor: scheme.surfaceContainerHighest`,
     `border` and `enabledBorder` = `OutlineInputBorder(borderRadius:
     BorderRadius.circular(NumerRadius.md), borderSide: BorderSide.none)`, `focusedBorder`
     the same with `BorderSide(color: scheme.primary, width: 2)`, `errorBorder` and
     `focusedErrorBorder` with `BorderSide(color: scheme.error, width: 2)`. Leave helper and
     error text styles at the Material defaults (they are `bodySmall` in
     `onSurfaceVariant` and `error`, as `DESIGN.md` 5.5 asks).
   - `filledButtonTheme`: `FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize:
     const Size(64, 48), shape: RoundedRectangleBorder(borderRadius:
     BorderRadius.circular(NumerRadius.md))))`. `FilledButton.tonal` reads the same theme.
   - `textButtonTheme`: the same `minimumSize` and `shape` with `TextButton.styleFrom`.
   - `segmentedButtonTheme`: `SegmentedButton.styleFrom(shape: RoundedRectangleBorder(
     borderRadius: BorderRadius.circular(NumerRadius.md)))`.
   - `bottomSheetTheme`: `backgroundColor` and `modalBackgroundColor`
     `scheme.surfaceContainerLow`, `elevation: 0`, `modalElevation: 0`, `shape:
     RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top:
     Radius.circular(NumerRadius.xl)))`. Do not set `showDragHandle` in the theme: existing
     sheets draw their own handle, and a theme handle would double it.
   - `floatingActionButtonTheme`: `elevation`, `focusElevation`, `hoverElevation`,
     `highlightElevation` and `disabledElevation` all 0, `backgroundColor:
     scheme.primaryContainer`, `foregroundColor: scheme.onPrimaryContainer`.
   Nothing else. In particular: no `textTheme`, no `fontFamily`, no `splashFactory`, no
   `cardTheme`, no `dialogTheme`.
2. Components, one file each under `packages/numer_ui/lib/src/components/`. Every size comes
   from `NumerSpace`, `NumerRadius`, `NumerMotion` or a private constant allowed by the
   Context. Every text style comes from `context.text`.
   - `numer_section.dart`: `NumerSection({required String title, String? actionLabel,
     VoidCallback? onAction, required Widget child})`. A `Padding(bottom: NumerSpace.xl)`
     around a `Column(crossAxisAlignment: start)`: a row padded `NumerSpace.lg` left and
     right with the title in `sectionTitle` (`Expanded`, at most 2 lines) and, when both
     `actionLabel` and `onAction` are given, a `TextButton`; then `SizedBox(height:
     NumerSpace.sm)`; then `child`. The child is not padded (a block pads itself; rows carry
     their own padding).
   - `numer_block.dart`: `NumerBlock({required List<Widget> children})`. `Padding(horizontal:
     NumerSpace.lg)` around a `Material(color: scheme.surfaceContainerHighest, borderRadius:
     BorderRadius.circular(NumerRadius.lg), clipBehavior: Clip.antiAlias)` holding a `Column`
     of the children with a `Divider(height: 1, thickness: 1, indent: NumerSpace.lg, color:
     scheme.outlineVariant)` between each two. No divider before the first or after the
     last. Assert that no child is a `NumerBlock`.
   - `numer_row.dart`: `NumerRow({Widget? leading, required String title, String? subtitle,
     String? value, Widget? trailing, bool showChevron = false, VoidCallback? onTap})`.
     Assert `value == null || trailing == null`, and that `showChevron` implies `onTap !=
     null`. Layout: `InkWell(onTap)` > `ConstrainedBox(minHeight: subtitle == null ? 56 :
     72)` > `Padding(horizontal: NumerSpace.lg, vertical: NumerSpace.sm)` > `Row(crossAxisAlignment:
     center)`: leading, `SizedBox(width: NumerSpace.md)` (only with a leading), `Expanded`
     column of title (`rowTitle`, `maxLines: 2`, ellipsis) and subtitle (`meta`, `maxLines: 1`,
     ellipsis, `SizedBox(height: NumerSpace.xs)` above it), then `value` as `Text` in
     `context.text.body.copyWith(color: scheme.onSurfaceVariant)`, then `trailing`, then
     `Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant)` when
     `showChevron`. `SizedBox(width: NumerSpace.sm)` between title column and each trailing
     part. Wrap in `Semantics(button: onTap != null)`.
   - `numer_shell_header.dart`: `NumerShellHeader({required Widget title, List<Widget>
     actions = const [], required Widget avatar, required String avatarTooltip, required
     VoidCallback onAvatarPressed})`. Assert `actions.length <= 2`. Returns a `SliverAppBar`
     (`centerTitle: false`, `backgroundColor: scheme.surface`, `surfaceTintColor:
     Colors.transparent`, `scrolledUnderElevation: 0`, `title: title`, `actions: [...actions,
     IconButton(tooltip: avatarTooltip, onPressed: onAvatarPressed, icon: SizedBox.square(
     dimension: 32, child: avatar)), const SizedBox(width: NumerSpace.xs)]`). The header does
     not know how to draw an avatar; the caller passes it.
   - `numer_module_scaffold.dart`: `NumerModuleScaffold({required String title, List<Widget>
     actions = const [], double? toolbarHeight, List<String>? tabLabels, List<Widget>?
     tabViews, Widget? body, Widget? floatingActionButton})`. Assert `actions.length <= 2`;
     exactly one of `body` and `tabLabels` is given; `tabLabels` and `tabViews` have the
     same length, at most 4. With tabs: a `DefaultTabController` around a `Scaffold` whose
     `AppBar` has `bottom: TabBar(tabs: [for (l in tabLabels) Tab(text: l)])` (text only,
     the theme's indicator, which is `primary`) and whose body is a `TabBarView`. Without
     tabs: a `Scaffold` with an `AppBar(title: Text(title), actions, toolbarHeight)` and
     `body`. `floatingActionButton` is passed to the `Scaffold`.
   - `numer_sheet.dart`: `Future<T?> showNumerSheet<T>(BuildContext context, {required String
     title, required WidgetBuilder builder, Widget? primaryAction})`. Calls
     `showModalBottomSheet<T>(context: context, useRootNavigator: true, isScrollControlled:
     true, useSafeArea: true, showDragHandle: true, backgroundColor:
     scheme.surfaceContainerLow, shape: <top radius NumerRadius.xl>, builder: ...)`. The
     builder returns `Padding(bottom: MediaQuery.viewInsetsOf(context).bottom)` > `SafeArea(top:
     false)` > `Column(mainAxisSize: min, crossAxisAlignment: stretch)`: the title in
     `sectionTitle` padded `NumerSpace.lg` left, right and bottom; `Flexible(child:
     SingleChildScrollView(padding: horizontal NumerSpace.lg, child: builder(context)))`; and,
     when given, `primaryAction` padded `NumerSpace.lg` on all sides (it stretches to full
     width).
   - `numer_confirm.dart`: `Future<bool> showNumerConfirm(BuildContext context, {required
     String title, String? body, required String confirmLabel, bool destructive = false})`.
     Uses `showNumerSheet<bool>` with `title`, the body as `Text` in `body` style, and as
     `primaryAction` a `Column` of a `FilledButton(onPressed: pop(true), child:
     Text(confirmLabel))` and, `SizedBox(height: NumerSpace.sm)` below it, a
     `TextButton(onPressed: pop(false), child:
     Text(MaterialLocalizations.of(context).cancelButtonLabel))`. When `destructive`, the
     filled button uses `FilledButton.styleFrom(backgroundColor: scheme.error,
     foregroundColor: scheme.onError)`. Returns `result ?? false`.
   - `numer_status_label.dart`: `enum NumerStatusTone { neutral, positive, caution, negative,
     highlighted }` and `NumerStatusLabel(String text, {NumerStatusTone tone =
     NumerStatusTone.neutral})`: a `Text` in `context.text.status(color)` where the colour is
     `onSurfaceVariant`, `NumerColors.success`, `NumerColors.warning`, `scheme.error`,
     `scheme.primary` in that order. No container.
   - `numer_skeleton.dart`: `NumerSkeleton({int rows = 3, bool twoLine = true})`. A stateful
     widget that shows `const SizedBox.shrink()` for the first 300 ms (a `Timer` started in
     `initState`, cancelled in `dispose`) and then `rows` static rows. Each row has the height
     of a `NumerRow` (72 when `twoLine`, else 56), padding `NumerSpace.lg` left and right, a
     title box 16 high at 60% of the row's inner width and, when `twoLine`, a meta box 12
     high at 35% width with `NumerSpace.xs` between them. Boxes: `DecoratedBox` with colour
     `scheme.onSurface.withValues(alpha: 0.08)` and radius `NumerRadius.sm`. No animation of
     any kind. The whole skeleton is excluded from semantics.
   - `numer_empty_state.dart`: `NumerEmptyState({required String message, String?
     actionLabel, VoidCallback? onAction, bool primaryAction = false})` and
     `numer_error_state.dart`: `NumerErrorState({required String message, required String
     retryLabel, required VoidCallback onRetry})`. Both: `Padding(top: NumerSpace.xxl, left
     and right NumerSpace.lg)` > `Column(mainAxisSize: min)`: the message in `body` with
     colour `onSurfaceVariant`, `textAlign: center`; `SizedBox(height: NumerSpace.md)`; the
     action as `TextButton` (or `FilledButton` when `primaryAction`). The error state always
     uses a `TextButton`. No icon, no illustration.
   - `numer_message.dart`: `void showNumerMessage(BuildContext context, String message, {bool
     isError = false, String? actionLabel, VoidCallback? onAction})`. Move the body of
     `showAppMessage` (`lib/shared/widgets/app_toast.dart:11-43`) here unchanged except:
     `BorderRadius.circular(16)` becomes `NumerRadius.lg`, the margin uses `NumerSpace.lg`.
     Keep `elevation: 4`, the 4 second duration, `FontWeight.w500` and the colours.
   - `numer_fab.dart`: `NumerFab({required IconData icon, required String label, required
     VoidCallback onPressed, bool visible = true})`. A `FloatingActionButton.extended(icon:
     Icon(icon), label: Text(label), onPressed: onPressed, heroTag: label)` (colours and zero
     elevation come from the theme), inside `IgnorePointer(ignoring: !visible)` inside
     `AnimatedSlide(offset: visible ? Offset.zero : const Offset(0, 2), duration:
     NumerMotion.of(context, NumerMotion.base), curve: visible ? NumerMotion.enter :
     NumerMotion.exit)` inside a `RepaintBoundary`. The screen decides `visible` from scroll
     direction; the component does not listen to scrolling.
3. `packages/numer_ui/lib/numer_ui.dart`: export `src/theme/numer_theme.dart` and the 13
   component files, in alphabetical order with the existing exports.
4. `lib/app/app_theme.dart`: `buildAppTheme(Color accent, Brightness brightness)` returns
   `NumerTheme.build(seed: accent, brightness: brightness)`. Keep the function name, the
   fallback themes and the import of `numer_ui`.
5. `lib/shared/widgets/app_toast.dart`: replace the body with a one-line forwarder:
   `showNumerMessage(context, message, isError: isError, actionLabel: actionLabel, onAction:
   onAction);`. Keep the signature and the comment above it.
6. `scripts/check_design.dart`: let `_exempt` map a pattern id to a list of path prefixes
   (`Map<String, List<String>>`, `_isExempt` checks `any(path.startsWith)`), and add
   `packages/numer_ui/lib/src/components/numer_message.dart` for `snackbar` and `shadow`.
   Run `dart run scripts/check_design.dart --write-baseline`. In the diff of
   `scripts/design_baseline.txt` the `lib/shared/widgets/app_toast.dart` lines disappear and
   no line for a file under `packages/numer_ui` appears.
7. Tests in `packages/numer_ui/test/` (golden-free; use `find`, `tester.getSize`,
   `tester.getRect`, `tester.widget`):
   - `numer_theme_test.dart`: for seed `0xFF448AFF` in both brightnesses: `useMaterial3`;
     `colorScheme.primary` equals `ColorScheme.fromSeed(...)`'s; the `NumerColors` extension
     matches the brightness; a `FilledButton` with a short label is 48 high and its shape
     radius is 12; a `TextField` is filled with `surfaceContainerHighest` and has no visible
     border until focused; the bottom sheet theme has a top radius of 20 and
     `surfaceContainerLow`; `appBarTheme.scrolledUnderElevation` is 0; the FAB theme
     elevation is 0; the switch theme's selected thumb is the seed.
   - `numer_row_test.dart`: one-line row is 56 high, two-line 72; title at 1.3 text scale
     with a long string grows the row instead of clipping; horizontal padding 16; leading to
     text gap 12; chevron only when `showChevron`; tap calls `onTap`; the assert fires for
     `value` plus `trailing`.
   - `numer_block_test.dart`: radius 16, fill `surfaceContainerHighest`; three rows give two
     dividers inset 16; the assert fires for a nested block.
   - `numer_section_test.dart`: title then child with 8 between; 24 below; the action shows
     only when both label and callback are given.
   - `numer_shell_header_test.dart`: inside a `CustomScrollView`, the avatar button is at
     least 48 by 48, its avatar 32 by 32, its tooltip is the given text, it is the rightmost
     action, tapping it calls the callback; three actions trigger the assert.
   - `numer_module_scaffold_test.dart`: with two tab labels a `TabBar` with two text tabs
     shows and switching shows the second view; without tabs the body shows and there is no
     `TabBar`; five tabs trigger the assert.
   - `numer_sheet_test.dart`: `showNumerSheet` opens on the root navigator (open it from a
     nested `Navigator` and find it above the nested route), has a drag handle, a top radius
     of 20 and the title; `showNumerConfirm` returns true on confirm, false on cancel and
     false when dismissed by tapping the scrim; with `destructive` the button colour is
     `error`; "Cancel" comes from `MaterialLocalizations`.
   - `numer_skeleton_test.dart`: after `pump(const Duration(milliseconds: 299))` nothing is
     drawn; after one more millisecond, `rows` rows of the right height; box colour alpha
     0.08; no `AnimationController` or `CircularProgressIndicator` in the tree.
   - `numer_states_test.dart`: empty and error states put the text 32 below their top, centre
     it, show one button; retry calls `onRetry`.
   - `numer_status_label_test.dart`: each tone gives its colour; no `DecoratedBox` or
     `Container` ancestor inside the widget.
   - `numer_message_test.dart`: shows a floating `SnackBar` for 4 seconds with radius 16; the
     error variant uses `errorContainer`; the action calls back.
   - `numer_fab_test.dart`: `visible: false` ignores taps and slides the button off; under
     `MediaQueryData(disableAnimations: true)` the switch takes zero time.
   - `gallery_images_test.dart`, tagged `images` like `otp_images_test.dart`: one image per
     brightness, at text scale 1.0 and 1.3, of a `CustomScrollView` holding a
     `NumerShellHeader`, a `NumerSection` with a `NumerBlock` of three `NumerRow`s (one with
     a leading icon and subtitle, one with a value and chevron, one with a `Switch`), a
     `NumerStatusLabel` of each tone, `NumerEmptyState`, `NumerErrorState`, a
     `NumerSkeleton` after 300 ms, and a `NumerFab`; plus one image each of an open
     `showNumerSheet`, an open `showNumerConfirm` (destructive) and a `showNumerMessage`
     toast. Use the seed `0xFF448AFF`. Write them under `test/goldens/` (already in
     `.gitignore`), generate with `--update-goldens`, attach to the report, do not commit.
8. Run `./scripts/verify.sh`.
9. Take before and after screenshots of the app (simulator or emulator, light and dark,
   EN): Home with a course, the add course sheet, the Settings tab, the sign-in screen. They
   show the effect of the theme on screens nobody edited (button shape and height, filled
   text fields, app bar titles).

## Non-goals
- Do not restyle any existing screen or change any call site of `showAppMessage`,
  `showModalBottomSheet` or `AlertDialog` (P3-12, P3-14).
- No compatibility layer for modules (P3-02). No module registry (P3-03).
- No new token, colour, radius, text style, icon package, font or dependency.
- Do not change `lightFallbackTheme`, `darkFallbackTheme` or the 300 ms theme animation in
  `lib/app/numer_app.dart`.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`. (This task adds none: the package takes its words as parameters.)
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`. `packages/numer_ui` imports nothing from `lib/` and depends on `flutter` only.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (the `packages/numer_ui` entry in `AGENTS.md` names what the package holds).
- No `TextStyle(`, `fontSize:`, `Colors.` other than `Colors.transparent`, `Color(0x`, `BoxShadow`, `Opacity(` or `CircularProgressIndicator` in any new file under `packages/numer_ui/lib/src/theme/` or `components/`, except what the existing exemptions and step 6 allow.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] `cd packages/numer_ui && flutter test` runs the 12 new test files and they pass.
- [ ] `grep -rn "package:numer_app" packages/numer_ui` prints nothing.
- [ ] `grep -rln "SnackBar(" packages/numer_ui/lib lib/shared` prints only `numer_message.dart`.
- [ ] `lib/shared/widgets/app_toast.dart` is a forwarder of at most 13 lines.
- [ ] `scripts/design_baseline.txt` has no line for `packages/numer_ui` and no count higher than before.
- [ ] Gallery images (both modes, text scale 1.0 and 1.3) and the four before and after app screenshots are attached to the report.
- [ ] The report answers each review item of `DESIGN.md` section 11 for the gallery with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Look at the before and after app screenshots and say whether the global button, field
  and app bar changes are acceptable for 2.0.

## Deliverable
Branch `numer2/p3-01-numer-ui-theme-components`, one commit, message `feat: add numer_ui theme builder and components` (subject line only). Do not push.
Report: files changed, test output, the images and screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- A screen in step 9 loses information or a control becomes hard to see (for example a text
  field whose fill equals the fill of the container it sits in).
- A `DESIGN.md` number cannot be met with the Material widget named here (report what you
  measured).
- Any contrast test in `contrast_test.dart` fails after the change.
