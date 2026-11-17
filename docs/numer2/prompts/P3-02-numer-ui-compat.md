# P3-02: `numer_ui`: compatibility layer for module code

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 8 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-01

## Goal
Let module code written against the four `app_ui` copies compile against `numer_ui` with
small, mechanical edits, and render with NUmer's tokens. Phase 4 moves each module onto this
layer; this task only builds it.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 2, 5, 9 and 11 (binding; section 9 is the mapping)
- `docs/numer2/DECISIONS.md` D-28, D-30 and D-39
- `docs/numer2/RESEARCH.md` section 8.1
- Everything under `packages/numer_ui/lib/` after P3-01
- Read-only inputs, the module repos cloned beside NUmer (on the owner's machine
  `~/gradus`, `~/Clavis`, `~/muto`, `~/events_bot`):
  - the base: `~/gradus/app_ui/lib/` (24 files) and `~/gradus/app_ui/test/` (3 files)
  - `~/Clavis/app_ui/lib/appbars/app_app_bar.dart:13,30,54` (`toolbarHeight`)
  - `~/muto/app_ui/lib/dialogs/app_bottom_sheet.dart:37,46` (`useRootNavigator`)
  - `~/muto/app_ui/lib/inputs/app_search_bar.dart:91,105` (`clearTooltip`, `filterTooltip`)
  - `~/muto/app_ui/lib/icons/app_icons.dart` (the extra icons and `clockHours` at line 360)

## Context
- Module code uses these `app_ui` names (call-site counts outside the `app_ui` folders, from
  a grep on 2026-11-27): `AppSpacing` 1362, `AppColors` 1062, `AppTextStyles` 372,
  `AppIcons` 221, `AppIcon` 115, `AppPrimaryButton` 60, `AppIconData` 55, `AppButtonSize` 48,
  `AppCard` 44, `AppTextField` 31, `AppSecondaryButton` 25, `AppLoader` 23, `AppTheme` 20,
  `AppBottomSheet` 15, `AppTextButton` 9, `AppSliverAppBar` 8 files, `AppIconButton` 7,
  `AppIconButtonSize` 6, `AppAppBar` 5, `AppToast` 3, `AppBottomSheetOption` 3,
  `AppProgressBar` 1, `GlobalSearchBar` 1 file, `HomeRadius` 8, `HomeShadows` 1.
- Names with no call site in any module, which this task does not carry: `AppListTile`,
  `AppSimpleAppBar`, `AppMenu`, `ToastManager`, `AppStepProgress`, `AppOtpField`,
  `AppShadows`, `AppTheme` (only standalone dev hosts use it; they build their own theme with
  `NumerTheme.build`), and the product widgets of `DESIGN.md` 9.4's last row. `AppCalendar`
  stays in the Events package.
- `AppColors` in the copies are `static const Color`. Scheme colours need a context, so the
  layer exposes `AppColors.of(context)` returning an object with the same member names
  (`DESIGN.md` 9.1). Modules change `AppColors.primary` to `AppColors.of(context).primary`.
- `AppTextStyles` in the copies are `static const TextStyle`. The layer exposes
  `AppTextStyles.of(context)` with the same member names, each resolved by the size and
  weight rule of `DESIGN.md` 9.2. Sizes and weights of the Gradus copy:
  displayLarge 57/400, displayMedium 45/400, displaySmall 36/400, headlineLarge 32/600,
  headlineMedium 28/600, headlineSmall 24/600, titleLarge 22/600, titleMedium 16/600,
  titleSmall 14/600, bodyLarge 16/400, bodyMedium 14/400, bodySmall 12/400, labelLarge
  14/500, labelMedium 12/500, labelSmall 11/500, button 16/600, buttonSmall 14/600, amount
  32/700, amountSmall 20/700, code 24/600, tab 14/500, tabSelected 14/600, chip 12/500,
  badge 10/600, link 14/500, hint 14/400, error 12/400, appBarTitle 18/600, sectionHeader
  16/600, statNumber 20/700, statLabel 12/400, username 14/500, timestamp 11/400.
- `AppSpacing` in the Gradus copy: `xs 4, sm 8, md 12, df 16, lg 20, xl 24, xxl 32, xxxl
  48, xxxxl 64`, padding and `SizedBox` presets built from them, radii `radiusXs 4, radiusSm
  8, radiusMd 12, radiusDf 16, radiusLg 20, radiusXl 24, radiusRound 100`, `BorderRadius`
  getters for each, `borderRadiusTopSheet` and `borderRadiusBottomSheet` (24), icon sizes
  `16, 20, 24, 32, 48`, avatar sizes `32, 40, 48, 64, 80, 100, 120`, button heights `40, 48,
  56`, `appBarHeight 56`, dividers `0.5, 1, 2`.
- `scripts/check_design.dart` holds the compat files to the same rules as every other file
  under `packages/`. No exemption is added for them.

## Steps
1. Create `packages/numer_ui/lib/compat.dart`, a second public library that exports
   `numer_ui.dart` and every file under `packages/numer_ui/lib/src/compat/`. Modules import
   `package:numer_ui/compat.dart`. `numer_ui.dart` does not export the compat files.
2. `src/compat/app_colors.dart`: `final class AppColors` with a private constructor taking
   `ColorScheme` and `NumerColors`, `static AppColors of(BuildContext context)`, and one
   `Color get` per name in this table (the first block is `DESIGN.md` 9.1; the second is
   D-39):

   | Names | Resolves to |
   |---|---|
   | `primary`, `primaryDark`, `primaryAccentDark` | `scheme.primary` |
   | `primaryLight`, `primaryLightDark` | `scheme.primaryContainer` |
   | `background` | `scheme.surface` |
   | `surface`, `surfaceDark`, `fieldBackground`, `serviceBackground`, `balanceCardBackground` | `scheme.surfaceContainerHighest` |
   | `textPrimary`, `textPrimaryDark`, `textColor`, `textColorDark` | `scheme.onSurface` |
   | `textSecondary`, `iconGrey` | `scheme.onSurfaceVariant` |
   | `textDisabled` | `scheme.onSurface.withValues(alpha: 0.38)` |
   | `borderGrey`, `borderDark`, `divider`, `dividerColor` | `scheme.outlineVariant` |
   | `success`, `lightGreen` | `numer.success` |
   | `warning` | `numer.warning` |
   | `error`, `errorText`, `errorTextDark` | `scheme.error` |
   | `info`, `lightBlue`, `socialTelegram` | `scheme.primary` |
   | `grey`, `iconSecondary` | `scheme.onSurfaceVariant` |
   | `iconPrimary` | `scheme.onSurface` |
   | `iconDisabled` | `scheme.onSurface.withValues(alpha: 0.38)` |
   | `white` | `scheme.onPrimary` |
   | `black` | `scheme.onSurface` |
   | `lightGrey` | `scheme.outlineVariant` |
   | `transparent` | `Colors.transparent` |
   | `orange` | `numer.warning` |
   | `green` | `numer.success` |
   | `blue` | `scheme.primary` |
   | `blueLight`, `infoLight` | `scheme.primaryContainer` |
   | `errorLight` | `scheme.errorContainer` |
   | `successLight`, `warningLight` | `scheme.surfaceContainerHighest` |
   | `socialWhatsapp` | `scheme.onSurfaceVariant` |

   No other member. Removed, and listed in `MIGRATION.md`: `primaryGradient`, `goldGradient`,
   `gold`, the avatar colours, the remaining social colours, `secondary`, `overlay`, `red`,
   `yellow`, `cyan`, `purple`, `purpleLight`, `deepPurple`, `deepPurpleLight`,
   `orangeLight`, `promotedBlue` (no module uses them).
3. `src/compat/app_text_styles.dart`: `final class AppTextStyles` with `static AppTextStyles
   of(BuildContext context)` and one `TextStyle get` per name in the Context list, resolved
   from `context.text` by `DESIGN.md` 9.2: size 22 and above, `screenTitle`; 16 to 20 at 600
   or 700, `sectionTitle`; 15 or 16 at 400 or 500, `rowTitle`; 14, `body`; 13 and below,
   `meta`. Exceptions, decided here: `displayLarge`, `displayMedium`, `displaySmall`,
   `amount` and `statNumber` resolve to `display` (the one large number); `button`,
   `buttonSmall`, `tab`, `tabSelected` resolve to `Theme.of(context).textTheme.labelLarge`
   (the button's own style); `link` is `body` in `scheme.primary`; `error` is `meta` in
   `scheme.error`; `chip` and `badge` are `meta`. Write the resulting table into
   `MIGRATION.md`.
4. `src/compat/app_spacing.dart`: `abstract final class AppSpacing` keeping every name of
   the Gradus copy, with values:
   - spacing doubles: each value equal to a `NumerSpace` value maps to that constant;
     `lg` (20) maps to `NumerSpace.lg` (16) and `xxxxl` (64) to `NumerSpace.xxxl` (48), the
     nearest lower token; `df` is `NumerSpace.lg`;
   - padding and `SizedBox` presets: rebuilt from the mapped doubles (`screenPadding`,
     `screenHorizontal`, `cardPadding` are `NumerSpace.lg` per `DESIGN.md` 9.2);
   - radii: `radiusXs` and `radiusSm` to `NumerRadius.sm`, `radiusMd` to `md`, `radiusDf`
     to `lg`, `radiusLg` and `radiusXl` to `xl`, `radiusRound` to `full`; the
     `BorderRadius` getters follow; `borderRadiusTopSheet` and `borderRadiusBottomSheet` use
     `NumerRadius.xl`;
   - icon sizes: `iconSm 16`, `iconMd 20`, `iconDf 24` keep their values (they are the three
     sizes of `DESIGN.md` 2.6); `iconLg` and `iconXl` become 24;
   - avatar sizes: `avatarSm 32`, `avatarMd 40`, `avatarDf 48` keep; the larger ones keep
     their values (they are content sizes, not chrome);
   - `buttonHeightSm`, `buttonHeightDf`, `buttonHeightLg` all 48; `appBarHeight` is
     `kToolbarHeight`; dividers keep `0.5, 1, 2`.
   Declare the non-token numbers as named constants at the top of the file. Also
   `abstract final class HomeRadius` with `card`, `cardBR` (a `BorderRadius`), `cardLg` at
   `NumerRadius.lg`, `button` at `md`, `pill` at `full` (open the Muto copy for each
   member's type), and `abstract final class HomeShadows` with `navBar` returning `const
   []`.
5. `src/compat/app_icons.dart`: `sealed class AppIconData` with the getter `IconData?
   get asIconData` (nullable, as in the Gradus copy) and one subclass
   `MaterialIcon(this.iconData)` whose `asIconData` returns `iconData` (the Gradus field
   name); `abstract final
   class AppIcons` with one `static const AppIconData` per row below, and `static const
   List<AppIconData> clockHours` of 12 entries, each `MaterialIcon(Icons.schedule_outlined)`,
   so `clockHours[i]` call sites compile. `src/compat/app_icon.dart`: `AppIcon(AppIconData
   icon, {double? size, Color? color, String? semanticLabel})` drawing an `Icon` (default
   size 24, default colour from `IconTheme`). The `colorFilter` parameter of the copies is
   removed (it existed for SVG). No `flutter_svg`, no asset path.

   | `AppIcons` | Material |
   |---|---|
   | `home` | `home_outlined` |
   | `back` | `arrow_back` |
   | `close`, `clear` | `close` |
   | `menu` | `menu` |
   | `hub`, `layoutGrid` | `grid_view_outlined` |
   | `layoutRows` | `view_agenda_outlined` |
   | `chevronRight`, `chevronLeft` | `chevron_right`, `chevron_left` |
   | `chevronUp`, `chevronDown` | `expand_less`, `expand_more` |
   | `moreVert`, `moreHoriz` | `more_vert`, `more_horiz` |
   | `edit` | `edit_outlined` |
   | `editProfile` | `manage_accounts_outlined` |
   | `delete` | `delete_outline` |
   | `save` | `save_outlined` |
   | `copy` | `content_copy` |
   | `search` | `search` |
   | `filter` | `tune` |
   | `share` | `share_outlined` |
   | `add` | `add` |
   | `addCircle` | `add_circle_outline` |
   | `check` | `check` |
   | `checkCircle` | `check_circle_outline` |
   | `markAsRead`, `doneAll` | `done_all` |
   | `send`, `telegram`, `twitter` | `send_outlined` |
   | `attach` | `attach_file` |
   | `logout` | `logout` |
   | `arrowForward` | `arrow_forward` |
   | `visibility` | `visibility_outlined` |
   | `visibilityOff`, `visibilityClosing` | `visibility_off_outlined` |
   | `profile` | `account_circle_outlined` |
   | `user` | `person_outline` |
   | `users`, `friends`, `people`, `facebook` | `group_outlined` |
   | `addAvatar` | `person_add_alt_outlined` |
   | `camera`, `instagram` | `photo_camera_outlined` |
   | `gallery` | `photo_library_outlined` |
   | `faceId` | `fingerprint` |
   | `avatarIcon` | `dashboard_outlined` |
   | `grade`, `star`, `starRounded` | `star_outline` |
   | `activity` | `show_chart` |
   | `trophy`, `awards` | `emoji_events_outlined` |
   | `leaderboard` | `leaderboard_outlined` |
   | `level` | `speed` |
   | `target`, `motivation` | `track_changes` |
   | `task`, `tasks` | `assignment_turned_in_outlined` |
   | `gem`, `diamond` | `diamond_outlined` |
   | `flame` | `local_fire_department_outlined` |
   | `gift` | `card_giftcard_outlined` |
   | `book`, `course` | `menu_book_outlined` |
   | `assignment` | `assignment_outlined` |
   | `chat`, `whatsapp` | `chat_outlined` |
   | `message` | `message_outlined` |
   | `notification` | `notifications_outlined` |
   | `transfer` | `swap_horiz` |
   | `sort` | `swap_vert` |
   | `statistics` | `bar_chart` |
   | `document` | `description_outlined` |
   | `request` | `quiz_outlined` |
   | `heart` | `favorite_border` |
   | `heartBroken` | `heart_broken_outlined` |
   | `fintech`, `trendingUp`, `trending` | `trending_up` |
   | `wallet` | `account_balance_wallet_outlined` |
   | `shieldAlert` | `gpp_maybe_outlined` |
   | `heartPulse` | `monitor_heart_outlined` |
   | `settings` | `settings_outlined` |
   | `security` | `verified_user_outlined` |
   | `language` | `language` |
   | `theme` | `brightness_6_outlined` |
   | `lock`, `lockOpen` | `lock_outline`, `lock_open_outlined` |
   | `error`, `alertCircle` | `error_outline` |
   | `warning` | `warning_amber_outlined` |
   | `info` | `info_outline` |
   | `sun`, `moon` | `light_mode_outlined`, `dark_mode_outlined` |
   | `wind` | `air` |
   | `image` | `image_outlined` |
   | `video` | `videocam_outlined` |
   | `school` | `school_outlined` |
   | `classroom` | `desktop_windows_outlined` |
   | `gym` | `fitness_center` |
   | `doorOpen` | `meeting_room_outlined` |
   | `megaphone` | `campaign_outlined` |
   | `openInNew` | `open_in_new` |
   | `utensils` | `restaurant_outlined` |
   | `briefcase` | `work_outline` |
   | `calendar` | `calendar_today_outlined` |
   | `event` | `event_outlined` |
   | `calendarMonth` | `calendar_month_outlined` |
   | `history` | `history` |
   | `time` | `schedule_outlined` |
   | `location` | `location_on_outlined` |
   | `email` | `mail_outline` |
   | `phone`, `call` | `phone_outlined`, `call_outlined` |
   | `link` | `link` |
   | `qrCode` | `qr_code` |
   | `refresh` | `refresh` |
   | `flag` | `flag_outlined` |

   Deleted (no glyph, or banned): `logo`, `token`, `bonus`, `points` (their SVG files do not
   exist), `sparkles` (`DESIGN.md` 2.6 bans it), the `avatar*Path` strings. Every entry of
   the Gradus and Muto copies is either in the table or in this list; if you find one that is
   in neither, stop and ask. Copy both tables into the report.
6. Parameters, for every widget of steps 7 to 11: keep every parameter that at least one
   call site outside the `app_ui` folders passes. Find them with `grep -rn "<Widget>(" -A12
   ~/gradus ~/Clavis ~/muto ~/events_bot --include='*.dart' | grep -v '/app_ui/\|/.claude/'`.
   Drop only parameters that set a colour, a radius, a border, a shadow or an elevation, and
   list each dropped one with its call-site count in `MIGRATION.md`. The parameter lists
   below are the minimum; the call sites win where they name more (known today:
   `AppProgressBar` takes `progress`, `label`, `showPercentage`; `AppAppBar` takes
   `showBackButton`, `onBackPressed`, `titleWidget`, `showDivider`, `centerTitle`;
   `AppBottomSheet.show` takes `maxHeightFraction`, `isDismissible`, `enableDrag`;
   `AppTextField` takes `validator`, `readOnly`, `textInputAction`, `textCapitalization`,
   `onTap`; `AppCard` takes `height`, `clipBehavior`, and `borderRadius` and
   `backgroundColor`, which are accepted and ignored so call sites compile, and listed in
   `MIGRATION.md` for removal).
7. `src/compat/app_buttons.dart`: `enum AppButtonSize { small, medium, large }`, `enum
   AppIconButtonSize { small, medium, large }`; `AppPrimaryButton` (`FilledButton`),
   `AppSecondaryButton` (`FilledButton.tonal`), `AppTextButton` (`TextButton`) with the
   Gradus parameters `text`, `onPressed`, `isLoading`, `isEnabled`, `icon`, `width`, `size`,
   and a `bool destructive = false` that replaces the colour parameters (`color` in Gradus
   and Clavis, `backgroundColor` in Muto are removed). Every size is 48 high; `width:
   double.infinity` stretches. The child is `NumerButtonChild(label: text, loading:
   isLoading)` with the icon before it when given and not loading; the button is disabled
   while loading or when `isEnabled` is false. `height` is removed. `AppIconButton({required
   AppIconData icon, required String tooltip, required VoidCallback? onPressed,
   AppIconButtonSize size = medium})` is an `IconButton`; `tooltip` is required (the copies
   had it optional).
8. `src/compat/app_inputs.dart`: `AppTextField` as a `TextField` with the theme's filled
   decoration, keeping the Gradus parameter names that set label, hint, helper, error,
   controller, focus node, keyboard type, obscure text, formatters, max length, max lines,
   enabled, `onChanged`, `onSubmitted`, prefix and suffix; drop parameters that set colours,
   radii or borders. `GlobalSearchBar` keeps the Gradus parameters plus Muto's
   `clearTooltip` and `filterTooltip`, now required whenever the clear or filter button can
   show.
9. `src/compat/app_containers.dart`: `AppCard({required Widget child, VoidCallback? onTap,
   EdgeInsetsGeometry? padding, ...})` draws the block surface itself, without
   `NumerBlock`'s side margin (module screens already pad themselves): a
   `Material(color: scheme.surfaceContainerHighest, borderRadius:
   BorderRadius.circular(NumerRadius.lg), clipBehavior: Clip.antiAlias)` around the child
   padded by `padding ?? EdgeInsets.all(NumerSpace.lg)`, inside an `InkWell` when `onTap`. `AppLoader({bool
   page = false})` is `NumerSkeleton()` when `page`, else `const SizedBox.shrink()`; record
   in `MIGRATION.md` that an action's loading state is the button's `isLoading`.
   `AppProgressBar({required double value})` is a `ClipRRect(radius: NumerRadius.full)` around
   a `LinearProgressIndicator(value, color: primary, backgroundColor:
   surfaceContainerHighest)`.
10. `src/compat/app_app_bars.dart`: `AppAppBar` (a `PreferredSizeWidget` around `AppBar`) and
   `AppSliverAppBar` (a `SliverAppBar`) with the Gradus parameters (`title`, `actions`,
   `leading`, `bottom` and those of step 6), and Clavis's `toolbarHeight` (default
   `kToolbarHeight`). Titles use the theme's app bar title style; colour and elevation
   parameters are removed. Assert at most two actions.
11. `src/compat/app_sheets.dart`: `AppBottomSheet.show<T>({required BuildContext context,
    required Widget child, String? title, bool useRootNavigator = true, ...the parameters of
    step 6})` over `showNumerSheet` (root navigator by default, as `DESIGN.md` 5.7 requires;
    the parameter exists so Muto call sites compile), keeping the Gradus safe-area bottom
    padding; `AppBottomSheet.showSelection<T>` with `AppBottomSheetOption<T>` rendering each
    option as a `NumerRow` inside the sheet, a selected option showing
    `Icon(Icons.check)` as trailing. `AppToast.showSuccess`, `showInfo`, `showWarning` call
    `showNumerMessage(context, message)`; `AppToast.showError` calls it with `isError:
    true`.
12. `packages/numer_ui/MIGRATION.md`: the steps a module performs, in order: replace
    `package:app_ui/app_ui.dart` with `package:numer_ui/compat.dart`; replace
    `AppColors.<name>` with `AppColors.of(context).<name>` and remove the `const` that no
    longer compiles; replace `AppTextStyles.<name>` with `AppTextStyles.of(context).<name>`;
    a table of every removed name and its replacement (removed colours: "use the role of the
    element, `DESIGN.md` 2.1"; removed widgets: the `DESIGN.md` 9.4 target; `AppTheme`:
    `NumerTheme.build(seed: <a seed the dev host declares>, brightness: ...)`;
    `AppPrimaryButton.color` and `.backgroundColor`: `destructive: true` when the colour was
    an error colour, otherwise remove); the colour, text style and icon tables of steps 2, 3
    and 5 and the dropped parameters of step 6; a grep the module runs afterwards: `grep -rn "app_ui\|AppColors\.[a-z]\|
    AppTextStyles\.[a-z]\|lucide\|google_fonts\|flutter_svg\|Geist"` must print nothing
    outside `AppColors.of` and `AppTextStyles.of` calls.
13. Tests under `packages/numer_ui/test/compat/` (no test file may spell
    `CircularProgressIndicator`: `check_design.dart` scans `packages/numer_ui/test/`; use
    `find.bySubtype<ProgressIndicator>()`):
    - `parity_test.dart`: a list of every name in the colour, text style, spacing and icon
      tables and the widget names of steps 7 to 11; for each, build a widget that reads it
      (`AppColors.of(context).primary`, `AppIcons.flag`, `AppSpacing.df`) so a missing name
      fails to compile, and assert a sample of resolutions (`AppColors.of(context).primary ==
      scheme.primary`, `AppColors.of(context).white == scheme.onPrimary`, `AppSpacing.lg ==
      16`, `AppSpacing.radiusRound == NumerRadius.full`, `AppTextStyles.of(context).titleLarge
      == context.text.screenTitle`, `AppIcons.whatsapp.asIconData == Icons.chat_outlined`,
      `AppIcons.clockHours.length == 12`).
    - `buttons_test.dart`: port `~/gradus/app_ui/test/button_loading_test.dart` (a loading
      button keeps its label, is disabled, shows one spinner); add: all sizes are 48 high,
      `destructive` uses `error`, `AppIconButton` without a tooltip does not compile (assert
      by the required parameter, no runtime test needed).
    - Port `~/gradus/app_ui/test/token_parity_test.dart` only where it still applies (token
      values that the tables keep); skip `app_menu_test.dart` (`AppMenu` is not carried).
    - `sheet_test.dart`: `AppBottomSheet.show` opens on the root navigator by default and
      pads the bottom safe area; `showSelection` returns the tapped value.
    - `dependencies_test.dart`: reads `packages/numer_ui/pubspec.yaml` and asserts the only
      entry under `dependencies` is `flutter`.
14. Run `./scripts/verify.sh`.

## Non-goals
- Do not edit any module repo (phase 4). Do not copy a module's `app_ui` tests that test
  widgets this task does not carry.
- Do not change any NUmer screen, `numer_ui.dart`'s exports or the P3-01 components.
- No new token, colour, radius, text style, icon package, font or dependency.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`. (This task adds none.)
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`. `packages/numer_ui` imports nothing from `lib/` and depends on `flutter` only.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. `scripts/check_file_size.sh` (in `verify.sh`) enforces it. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit; when it is split away, remove its entry. Never add a new path to the baseline.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- The module repos are read-only inputs. Do not run `git` commands that change them.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0, including `check_design.sh` with no exemption added for `src/compat/`.
- [ ] `grep -rni "lucide\|google_fonts\|flutter_svg\|simple_icons\|geist" packages/numer_ui` prints nothing.
- [ ] `grep -rn "Color(0x\|TextStyle(\|fontSize:" packages/numer_ui/lib/src/compat` prints nothing.
- [ ] `packages/numer_ui/test/compat/parity_test.dart` names every row of the four tables and passes.
- [ ] `packages/numer_ui/MIGRATION.md` exists with the steps and tables of step 11.
- [ ] The report contains the full icon table and the list of deleted names.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated (the `packages/numer_ui` entry in `AGENTS.md` mentions `compat.dart`), or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p3-02-numer-ui-compat`, one commit, message `feat: add numer_ui compatibility layer for modules` (subject line only). Do not push.
Report: files changed, test output, the icon table, deleted names, anything you could not verify, user actions still pending.

## Stop and ask if
- A module repo is not at the path given.
- A widget used by a module has behaviour `DESIGN.md` forbids (a gradient button, a shadowed
  card, a coloured chip) and no row of section 9 or of this prompt covers it.
- An `AppIcons` entry of the Gradus or Muto copy is in neither the table nor the deleted list.
- A parameter of a carried widget is used by a module and is not listed here (grep the
  module repos before removing a parameter; report the ones you kept).
