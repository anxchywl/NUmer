# Moving a module from `app_ui` to `numer_ui`

`package:numer_ui/compat.dart` keeps the names module code uses and draws them with NUmer's
tokens. The host and a module's own dev host build their theme with `NumerTheme.build`;
`AppColors.of` reads the `NumerColors` extension that theme carries. New module code uses
the `Numer*` names.

## Steps

1. Replace `package:app_ui/app_ui.dart` with `package:numer_ui/compat.dart`, and the
   `app_ui` entry in `pubspec.yaml` with `numer_ui`.
2. Replace `AppColors.<name>` with `AppColors.of(context).<name>` and remove the `const`
   that no longer compiles. Code that chose between `X` and `XDark` by brightness reads one
   name.
3. Replace `AppTextStyles.<name>` with `AppTextStyles.of(context).<name>`.
4. Apply "Behaviour that changed" and replace every removed name and parameter below.
5. Move every sheet and dialog with a text field to "Focus mode".
6. Run the check; it must print nothing but `AppColors.of` and `AppTextStyles.of` calls:

```bash
grep -rn "app_ui\|AppColors\.[a-z]\|AppTextStyles\.[a-z]\|[l]ucide\|google[_]fonts\|flutter[_]svg\|[G]eist" --include='*.dart' --include=pubspec.yaml .
```

## Behaviour that changed

These compile unchanged or nearly so, and behave differently:

- **Loading buttons** show only a centred spinner; the label and icon stay in the layout,
  invisible, so the button keeps its size. A button that passes `isLoading` also passes
  `loadingHint`, the localized word a screen reader hears; a debug assert requires it.
- **Button width**: buttons were full width by default. Now they take their label's width;
  pass `width: double.infinity` where a full-width button is meant.
- **Button size**: every `AppButtonSize` is 48 high. `AppButtonSize.height` and `.padding`
  are gone.
- **`AppIconButton`**: `icon` is an `AppIconData`, not a widget (`icon: AppIcons.back`), and
  `tooltip` is required. `AppIconButtonSize` sets the glyph to 16, 20 or 24;
  `.containerSize` and `.iconSize` are gone.
- **`AppLoader()` draws nothing.** An action's loading state is the button's `isLoading`; a
  page or list that is loading uses `AppLoader(page: true)`, a skeleton.
- **`AppProgressBar`** track is `surfaceContainerHighest`, the same role as a card, so keep
  the bar on the page surface.
- **`AppAppBar`, `AppSliverAppBar`** allow at most two actions, and `centerTitle` follows
  the theme (start aligned) unless passed.
- **`GlobalSearchBar`** requires `clearTooltip` when it has a `controller` and
  `filterTooltip` when `showFilterButton` is true.
- **`AppBottomSheet.show`** opens on the root navigator unless `useRootNavigator: false`.
  Its content still pads itself.
- **`AppIcons.clockHours`** is twelve equal glyphs, so an hour-stepping animation holds
  still, and a test that expects distinct frames has to go.
- **Brand icons** (`telegram`, `whatsapp`) are generic glyphs: show the brand name beside
  them.

## Focus mode

Every sheet or dialog with a text field uses focus mode (`DESIGN.md` 5.7): while the
keyboard is up only the active field stays, and the actions become one "Done" button. The
compat names do not provide it, and `AppBottomSheet.show` cannot fold its own title, so such
a sheet moves to the `Numer*` pieces. A module's own `focus_mode.dart` is deleted.

1. Open the sheet with `showNumerFormSheet<T>(context, builder: ...)`. It uses the root
   navigator, so a sheet that read an inherited scope below a nested navigator passes that
   scope into the builder.
2. The form's `State` creates a `NumerSheetFocusMode` in `initState` and disposes it in
   `dispose`.
3. Build a `NumerSheetBody` with `title`, `focusMode`, the submit button as `primaryAction`
   and a localized `doneLabel`. A form with one field leaves `doneLabel` null, so its submit
   button stays while typing. The body already scrolls, pads the sides and follows the
   keyboard, so the form drops its own.
4. In `NumerSheetBody.builder`, give each field `focusNode: focus.nodeFor(id)`, wrap it with
   its label and helper text in `NumerFocusFold(hidden: focus.hides(id))`, put
   `NumerFocusGap(hidden: focus.hidesChrome)` between fields, and fold everything else with
   `NumerFocusFold(hidden: focus.hidesChrome)`.
5. "Next" on the keyboard calls `focus.moveTo(nextId)`; the last field calls
   `focus.release()`.

A sheet that cannot be a `NumerSheetBody`, such as a stepped flow with its own header, keeps
its body inside `showNumerFormSheet`. It calls
`focus.setKeyboardVisible(MediaQuery.viewInsetsOf(context).bottom > 0)` in `build`, rebuilds
through `ListenableBuilder(listenable: focus, ...)` and places its actions in
`NumerFocusActions(isTyping: focus.isTyping, doneLabel: ..., onDone: focus.release,
actions: ...)`.

| Module copy | `numer_ui` |
|---|---|
| `SheetFocusMode` | `NumerSheetFocusMode` |
| `FocusFold`, `FocusGap` | `NumerFocusFold`, `NumerFocusGap` |
| `FocusModeActions` | `NumerFocusActions` |
| `focusModeDuration` | `NumerFocusFold.durationOf(context)` |
| `FocusModeActions.donePadding` (Muto) | one `Padding` around `NumerFocusActions`, none inside `actions` |
| `SheetFocusMode.typingIn` (Muto) | `isTyping`, `hides(id)` |

Sheets with a text field on 2026-11-27:

| Module | File | Today |
|---|---|---|
| Gradus | `course_form.dart`, `assignment_form.dart`, `semester_form.dart` | own `focus_mode.dart` |
| Muto | `report/report_sheet.dart` | own `focus_mode.dart`, one field, `AppBottomSheet.show` |
| Muto | `editor/listing_editor_sheet.dart` | own `focus_mode.dart`, stepped, own `showModalBottomSheet` on the nested navigator |
| Events | `submit/submit_screen.dart` (`asSheet: true`, opened from `events_screen.dart` and `event_detail_screen.dart`) | no focus mode |
| Events | `events/event_detail_screen.dart`, `_ModerationCommentSheet` | no focus mode |
| Events | `events/events_screen.dart`, `_MultiSelectSheet` with `withSearch` | no focus mode |
| Events | `event_manager/analytics_event_picker.dart`, `GlobalSearchBar` in `AppBottomSheet.show` | no focus mode |

## Removed parameters

Counts are module call sites outside the `app_ui` folders on 2026-11-27.

| Widget | Parameter (call sites) | Replacement |
|---|---|---|
| `AppPrimaryButton` | `color` (2), `backgroundColor` (2) | `destructive: true` when it was an error colour, otherwise remove |
| `AppPrimaryButton`, `AppSecondaryButton` | `height` (0) | remove |
| `AppSecondaryButton` | `borderColor` (3), `textColor` (3) | `destructive: true` when it was an error colour, otherwise remove |
| `AppTextButton` | `textColor` (0), `underline` (0) | `destructive: true` for an error colour, otherwise remove |
| `AppIconButton` | `iconColor` (1), `backgroundColor` (0), `isEnabled` (0), `isLoading` (0) | remove; pass `onPressed: null` to disable. A colour set on the old `AppIcon` child goes too |
| `AppTextField` | `filled` (0), `fillColor` (0), `borderRadius` (0) | remove |
| `AppCard` | `border` (1), `elevation` (0) | remove |
| `AppLoader` | `size` (0), `color` (0), `strokeWidth` (0), `centered`, `overlay`, `showDialog`, `hideDialog` (0) | see above |
| `AppProgressBar` | `height` (0), `animate` (0), `backgroundColor` (0), `progressColor` (0), `borderRadius` (0) | remove |
| `AppAppBar` | `backgroundColor` (0), `elevation` (0) | remove |
| `AppIcon` | `colorFilter` (0) | `color` |

`AppCard.backgroundColor` (4) and `AppCard.borderRadius` (6) are accepted and ignored so call
sites compile. Delete them; the parameters are removed once no module passes them.

## Removed names

| Name | Replacement |
|---|---|
| colours `primaryGradient`, `goldGradient`, `gold`, `secondary`, `overlay`, `red`, `yellow`, `cyan`, `purple`, `purpleLight`, `deepPurple`, `deepPurpleLight`, `orangeLight`, `promotedBlue`, `socialTwitter`, `socialFacebook`, `socialInstagram`, `avatar1` to `avatar5` | use the role of the element, `DESIGN.md` 2.1 |
| text styles `balance`, `cardNumber` | `context.text.display` or `context.text.body` |
| icons `logo`, `token`, `bonus`, `points` | delete the use; their SVG files never existed |
| icon `sparkles` | delete the use; `DESIGN.md` 2.6 bans it |
| `avatar1Path` to `avatar4Path`, `defaultAvatarPath` | the module's own asset path |
| `SvgIcon`, `AppIconPresets` | `AppIcons`; `AppIcon(icon, size: ...)` |
| `HomeRadius.navIndicator`, `circle`, `cardLgBR`, `buttonBR`, `pillBR`, `circleBR` | `NumerRadius`, `DESIGN.md` 2.4 |
| `HomeShadows.card`, `floating`, `studentCard`, `AppShadows` | no shadow |
| `HomeSpacing` | the nearest lower `NumerSpace` value |
| `HomeCardStyle`, `AppCardWithHeader` | `NumerSection` over an `AppCard` |
| `AppListTile` | `NumerRow` |
| `AppSimpleAppBar` | `AppAppBar(title: ..., showBackButton: true)` |
| `AppMenu`, `AppMenuItem` | `MenuAnchor` with the theme |
| `ToastManager`, `ToastType` | `AppToast` or `showNumerMessage` |
| `AppLoaderSize` | none |
| `AppCircularProgress`, `AppStepProgress` | `LinearProgressIndicator` with `primary` on `surfaceContainerHighest` |
| `AppOtpField` | `NumerOtpField` |
| `AppTheme` | `NumerTheme.build(seed: <a seed the dev host declares>, brightness: ...)` |
| `AppCalendar`, `AppCalendarEvent` | stay in the Events package, restyled with tokens |
| `AppBankCard`, `BankCardType`, `AppUserCard`, `AppJobCard`, `AppPremiumDialog`, `AppLevelRing`, `LevelUpData`, `RewardItem`, `RewardToastManager`, `RewardToastType`, `AppPasswordField`, `AppPhoneField` | deleted, `DESIGN.md` 9.4 |

## Colours

| `AppColors.of(context)` | Resolves to |
|---|---|
| `primary`, `primaryDark`, `primaryAccentDark`, `info`, `lightBlue`, `socialTelegram`, `blue` | `scheme.primary` |
| `primaryLight`, `primaryLightDark`, `blueLight`, `infoLight` | `scheme.primaryContainer` |
| `background` | `scheme.surface` |
| `surface`, `surfaceDark`, `fieldBackground`, `serviceBackground`, `balanceCardBackground`, `successLight`, `warningLight` | `scheme.surfaceContainerHighest` |
| `textPrimary`, `textPrimaryDark`, `textColor`, `textColorDark`, `iconPrimary`, `black` | `scheme.onSurface` |
| `textSecondary`, `iconGrey`, `grey`, `iconSecondary`, `socialWhatsapp` | `scheme.onSurfaceVariant` |
| `textDisabled`, `iconDisabled` | `scheme.onSurface.withValues(alpha: 0.38)` |
| `borderGrey`, `borderDark`, `divider`, `dividerColor`, `lightGrey` | `scheme.outlineVariant` |
| `success`, `lightGreen`, `green` | `NumerColors.success` |
| `warning`, `orange` | `NumerColors.warning` |
| `error`, `errorText`, `errorTextDark` | `scheme.error` |
| `white` | `scheme.onPrimary` |
| `transparent` | `Colors.transparent` |
| `errorLight` | `scheme.errorContainer` |

## Text styles

| `AppTextStyles.of(context)` | Resolves to |
|---|---|
| `displayLarge`, `displayMedium`, `displaySmall`, `amount`, `statNumber` | `context.text.display` |
| `headlineLarge`, `headlineMedium`, `headlineSmall`, `titleLarge`, `code` | `context.text.screenTitle` |
| `titleMedium`, `amountSmall`, `appBarTitle`, `sectionHeader` | `context.text.sectionTitle` |
| `titleSmall`, `bodyMedium`, `labelLarge`, `hint`, `username` | `context.text.body` |
| `bodyLarge` | `context.text.rowTitle` |
| `bodySmall`, `labelMedium`, `labelSmall`, `chip`, `badge`, `statLabel`, `timestamp` | `context.text.meta` |
| `button`, `buttonSmall`, `tab`, `tabSelected` | `theme.textTheme.labelLarge` |
| `link` | `context.text.body.copyWith(color: theme.colorScheme.primary)` |
| `error` | `context.text.meta.copyWith(color: theme.colorScheme.error)` |

`link` is `body` in `primary`; `error` is `meta` in `error`.

## Spacing and radii

| `AppSpacing` | Value |
|---|---|
| `xs`, `sm`, `md`, `xl`, `xxl`, `xxxl` | unchanged: 4, 8, 12, 24, 32, 48 |
| `df`, `lg` | 16 (`lg` was 20) |
| `xxxxl` | 48 (was 64) |
| padding and `SizedBox` presets | built from the values above; `chipPadding` is 4 high (was 6) |
| `radiusXs`, `radiusSm` | 8 (`radiusXs` was 4) |
| `radiusMd`, `radiusDf` | 12, 16 |
| `radiusLg`, `radiusXl`, both sheet radii | 20 (`radiusXl` and the sheets were 24) |
| `radiusRound` | 999 |
| `iconSm`, `iconMd`, `iconDf` | 16, 20, 24 |
| `iconLg`, `iconXl` | 24 (were 32, 48) |
| `avatar*` | unchanged |
| `buttonHeightSm`, `buttonHeightDf`, `buttonHeightLg` | 48 |
| `appBarHeight` | `kToolbarHeight` |
| `dividerThin`, `dividerDf`, `dividerThick` | unchanged |
| `HomeRadius.card`, `cardBR`, `cardLg` | 16 |
| `HomeRadius.button`, `pill` | 12, 999 |
| `HomeShadows.navBar` | empty |

## Icons

| `AppIcons` | Material `Icons` |
|---|---|
| `home` | `home_outlined` |
| `back` | `arrow_back` |
| `close`, `clear` | `close` |
| `menu` | `menu` |
| `hub`, `layoutGrid` | `grid_view_outlined` |
| `layoutRows` | `view_agenda_outlined` |
| `chevronRight` | `chevron_right` |
| `chevronLeft` | `chevron_left` |
| `chevronUp` | `expand_less` |
| `chevronDown` | `expand_more` |
| `moreVert` | `more_vert` |
| `moreHoriz` | `more_horiz` |
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
| `lock` | `lock_outline` |
| `lockOpen` | `lock_open_outlined` |
| `error`, `alertCircle` | `error_outline` |
| `warning` | `warning_amber_outlined` |
| `info` | `info_outline` |
| `sun` | `light_mode_outlined` |
| `moon` | `dark_mode_outlined` |
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
| `phone` | `phone_outlined` |
| `call` | `call_outlined` |
| `link` | `link` |
| `qrCode` | `qr_code` |
| `refresh` | `refresh` |
| `flag` | `flag_outlined` |
| `clockHours` (12 equal entries) | `schedule_outlined` |
