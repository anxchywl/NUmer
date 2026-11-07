# NUmer 2.0 design language

Binding for every task that touches UI, in NUmer and in every module. It is written so that
an executor needs no taste judgment: if a value or a pattern is not in this document, do not
invent one. Stop and ask.

It keeps the look NUmer has today (Material 3 generated from the user's accent colour, the
system font, flat surfaces) and fixes the scale that today varies from screen to screen.
Evidence for "today" is in `RESEARCH.md` section 8; decisions are in `DECISIONS.md` D-20 and
D-28 to D-32.

Sections:

1. Rules of use
2. Tokens
3. Navigation and information architecture
4. Screen layouts: Home, News, Study, Campus, Settings
5. Components
6. States: loading, empty, error, offline
7. Motion and haptics
8. Copy
9. Modules: how `app_ui` maps onto this
10. Performance budgets
11. Banned patterns and the mechanical checks
12. What a UI task must deliver

---

## 1. Rules of use

1. New and changed UI uses only the tokens in section 2 and the components in section 5,
   imported from `package:numer_ui/numer_ui.dart`.
2. Existing screens are not restyled unless the task says so. When a task edits a widget, it
   brings that widget (not the whole file) to the tokens.
3. One accent: the user's seed colour, through `Theme.of(context).colorScheme`. No other hue
   is introduced by the interface.
4. Hierarchy comes from type and spacing. A screen has exactly one primary element: one
   filled button, or one large number, never both competing.
5. Lists of real content come first. No grids of decorative tiles, no rows of equal cards.
6. A container holds one self-contained item. No container inside a container.
7. Dark mode is designed, not derived by accident: every UI task shows both.
8. If this document and a module's own styling disagree, this document wins.

---

## 2. Tokens

All tokens live in `packages/numer_ui/lib/src/tokens/`. Names below are the Dart names.

### 2.1 Colour roles

The scheme is `ColorScheme.fromSeed(seedColor: accent, brightness: brightness)`, built once
by `NumerTheme.build({required Color seed, required Brightness brightness})`. Use roles,
never literals.

| Use | Role |
|---|---|
| Page background, app bars, tab bars | `surface` |
| Block (a grouped set of rows), filled text field, image placeholder, skeleton base | `surfaceContainerHighest` |
| Bottom sheet and menu background | `surfaceContainerLow` |
| Primary text, icons that act | `onSurface` |
| Secondary text, meta, inactive icons, chevrons | `onSurfaceVariant` |
| Disabled text and icons | `onSurface` at alpha 0.38 |
| Divider, hairline border | `outlineVariant` |
| Screen title, the one primary action, selected state, links, progress fill | `primary` |
| Text and icon on a primary fill | `onPrimary` |
| Tonal button, selected row background | `primaryContainer` with `onPrimaryContainer` |
| Error text, destructive action | `error` |
| Error banner background | `errorContainer` with `onErrorContainer` |
| Scrim over an image (text on a photo) | `scrim` at alpha 0.5 |

Two semantic colours the scheme lacks come from the theme extension `NumerColors`
(`Theme.of(context).extension<NumerColors>()!`):

| Token | Light | Dark | Use |
|---|---|---|---|
| `success` | `0xFF0F6B2E` | `0xFF81C995` | a positive status label, a completed check |
| `warning` | `0xFF8A4B00` | `0xFFFDD663` | a caution status label |

Rules:
- `info` does not exist; use `primary`.
- Data colours (a course colour, a habit colour, a category colour chosen by the user) are
  content. They appear only as a 10 pt dot, a 40 pt avatar fill, a chart series, or a
  calendar cell. They never colour text, borders, backgrounds of rows, or buttons.
- Alpha is applied with `withValues(alpha: x)`. Allowed alpha values: 0.08 (skeleton), 0.12
  (pressed or selected overlay), 0.38 (disabled), 0.5 (scrim).
- `Colors.transparent` is allowed. Every other `Colors.*` and every `Color(0x...)` is banned
  outside `packages/numer_ui/lib/src/tokens/`, the avatar catalogue, and user colour presets.
- The two splash backgrounds shown before the theme exists (`0xFF121212`, `0xFFFFFFFF`) stay.

Contrast is tested, not assumed: `packages/numer_ui/test/contrast_test.dart` builds the light
and dark scheme for the five accent presets and asserts `onSurface` and `onSurfaceVariant`
on `surface` and on `surfaceContainerHighest` at 4.5:1 or more, `primary` on `surface` at
3:1 or more, and `success`, `warning`, `error` on both surfaces at 4.5:1 or more.

### 2.2 Type scale

System font. Never set `fontFamily`. Text styles come from `context.text` (the `NumerText`
extension), which reads the Material text theme and applies the weight and colour below.

| Name | Material base | Size / line | Weight | Colour | Use |
|---|---|---|---|---|---|
| `display` | `displayMedium` | 45 / 52 | 400, tabular figures | `onSurface` | a running clock, a GPA value. At most one per screen |
| `screenTitle` | `titleLarge` | 22 / 28 | 700 | `primary` | the title of a tab root or a pushed screen |
| `sectionTitle` | `titleMedium` | 16 / 24 | 700 | `onSurface` | the heading of a section |
| `rowTitle` | `bodyLarge` | 16 / 24 | 400 | `onSurface` | the main line of a list row, form text |
| `body` | `bodyMedium` | 14 / 20 | 400 | `onSurface` | paragraphs, sheet text |
| `meta` | `bodySmall` | 12 / 16 | 400 | `onSurfaceVariant` | secondary line, time, source, helper text |
| `status` | `labelMedium` | 12 / 16 | 500 | by state | the single status label of a row |
| button text | `labelLarge` | 14 / 20 | 500 | from the button | never styled by hand |

Rules:
- Allowed weights: 400, 500, 700. Nothing else.
- No `TextStyle(` and no `fontSize:` outside `packages/numer_ui/lib/src/tokens/`.
- At most five of these styles on one screen.
- Never shrink text for a language. A label that does not fit wraps to two lines, then
  ellipsizes. Rows grow in height; no fixed-height text containers.
- Layouts hold at a system text scale of 1.3.
- Numbers that change in place (clocks, counters) use tabular figures:
  `FontFeature.tabularFigures()`.

### 2.3 Spacing

A 4 pt grid. Only these values, from `NumerSpace`:

| Token | Value | Typical use |
|---|---|---|
| `xs` | 4 | icon to its label, title to its meta line |
| `sm` | 8 | between related controls |
| `md` | 12 | leading element to text in a row; between blocks in a section |
| `lg` | 16 | screen side padding; inner padding of blocks and sheets |
| `xl` | 24 | between sections |
| `xxl` | 32 | top padding of an empty or error state |
| `xxxl` | 48 | bottom clearance above a floating action |

- Screen side padding is always `lg` (16).
- Space between two sections is `xl` (24). Space between a section title and its content is
  `sm` (8).
- Use `SizedBox` and `EdgeInsets` with these constants only. No literal numbers.

### 2.4 Radii

From `NumerRadius`. Each value has one job.

| Token | Value | Used for |
|---|---|---|
| `sm` | 8 | thumbnails up to 56 pt, skeleton lines, small tags inside data views |
| `md` | 12 | buttons, text fields, segmented controls, images in rows |
| `lg` | 16 | blocks, toasts, hero images |
| `xl` | 20 | the top corners of bottom sheets |
| `full` | 999 | avatars, dots, the floating action |

Material's own defaults stay for system dialogs. The floating iOS tab bar keeps its own radii
(34 and 28); it is the single grandfathered component.

### 2.5 Elevation, borders, shadows

- Elevation is 0 everywhere, including the floating action. Separation comes from a surface
  role or a 1 px `outlineVariant` divider.
- No `BoxShadow` in new UI. The only shadows that remain are the toast's default and the iOS
  tab bar highlight.
- An element gets at most one of: a fill, a border. Never both, and never a fill plus a
  border plus a tint. One exception: a filled input shows focus or an error with a 2 px
  border (`primary` or `error`) on top of its fill.
- No coloured stripe on the side of a container.

### 2.6 Icons

- One family: Material `Icons`. Outlined variant by default (`Icons.event_outlined`); the
  filled variant only for a selected state (the active tab, a set favourite).
- Sizes: 24 in rows, app bars and tab bars; 20 for a trailing chevron; 16 inline with `meta`
  text.
- Colour: `onSurfaceVariant`, or `onSurface` when the icon is itself the action, or
  `primary` when selected.
- An icon appears only where it helps scanning. Rows in a list of the same kind either all
  have a leading icon or none do. No icon inside a coloured circle.
- Every icon-only control has a `tooltip`.
- No emoji anywhere. No sparkle, wand or star icon for AI features.
- Outside this rule, as content: the avatar catalogue and habit icons chosen by users
  (`DECISIONS.md` D-30).

### 2.7 Touch targets

Every interactive element is at least 48 by 48 pt, even when its visual is smaller.

---

## 3. Navigation and information architecture

### 3.1 Tabs

Five destinations, in this order. The Campus tab is shown only when at least one campus
module is visible to the user; otherwise the bar has four items.

| # | Label EN / RU / KK | Icon (inactive / active) | Root screen |
|---|---|---|---|
| 1 | Home / Главная / Басты | `home_outlined` / `home` | Home |
| 2 | Habits / Привычки / Әдеттер | `check_circle_outline` / `check_circle` | Habits |
| 3 | Study / Учёба / Оқу | `school_outlined` / `school` | Study |
| 4 | Groups / Группы / Топтар | `group_outlined` / `group` | Groups |
| 5 | Campus / Кампус / Кампус | `apartment_outlined` / `apartment` | Campus |

Reuse the existing ARB keys for Home, Habits and Groups. Add `navStudy` and `navCampus`.

The bars themselves do not change visually:
- iOS: the existing floating bar (`RESEARCH.md` 8.4), fed from the destination list.
- Android: the existing Material `NavigationBar`.
- No haptic on tab change (as today).

### 3.2 Tab root header

Every tab root uses `NumerShellHeader` (a `SliverAppBar`, `centerTitle: false`, background
`surface`, no elevation when scrolled under):

- Title: the `screenTitle` text of the tab. Home keeps its streak title widget in that slot.
- Actions, right to left: the avatar button (the user's avatar at 32 pt inside a 48 pt
  target, tooltip "Settings", opens Settings), then at most two icon actions for that tab.
- The Habits "Progress / List" switch leaves the title slot and becomes a `SegmentedButton`
  directly under the header.

### 3.3 Pushed screens and modules

- A pushed screen has a plain `AppBar`: back arrow, `screenTitle`, at most two icon actions.
- Every pushed screen covers the tab bar (it is pushed on the root navigator). There is never
  a second bottom bar.
- A module opens as a pushed screen wrapped in `NumerModuleScaffold`:
  - app bar as above, title = the module name;
  - optional sections as a text-only Material `TabBar` under the app bar (at most four tabs,
    indicator `primary`, labels in sentence case). This replaces any bottom bar the module
    had on its own;
  - at most one floating action (section 5.6).
- Short tasks (add, edit one item, confirm, pick) are bottom sheets, not screens.
- Navigation depth: tab root, then one screen, then at most one more. Deeper flows are
  sheets.

### 3.4 Module registry

A module is one `ModuleDescriptor` in `lib/app/modules/module_registry.dart`:
`id`, `titleKey`, `subtitleKey`, `icon`, `section` (`study` or `campus`), `flagId`, and a
lazy `builder`. The Study and Campus roots render the visible descriptors as rows. Adding a
module never changes the tab bar.

### 3.5 Where everything goes

| Existing screen or element | NUmer 2.0 location |
|---|---|
| Home: streak title | Home header title, unchanged |
| Home: sync status pill | Home header, shown only when offline or failing, as `meta` text under the title; hidden when up to date |
| Home: active session bar | Home, top, unchanged; also shown at the top of Study |
| Home: course list, reorder, swipe to delete | Study root, "Courses" section, unchanged behaviour |
| Home: course time sheet (timer, stopwatch, pomodoro) | unchanged; opened from a course row in Study, and from "Continue" on Home |
| Home: add course (pill or FAB) | Study header action (`add`) and the empty-state button |
| Home: AI analysis (pill or FAB) | Study root, row "Course analysis" |
| Home: goals popup from the credits badge | unchanged, from the course row in Study |
| Habits tab and its sub-screens | Habits tab, unchanged apart from the header switch |
| Statistics tab | screen pushed from the Study row "Statistics" |
| History | screen pushed from the Study row "History", and from Statistics as today |
| Habit report download | stays in Statistics |
| Groups tab, leaderboard, member sheet, manage screen | Groups tab, unchanged |
| Account tab ("Settings") | Settings screen, opened from the avatar |
| Calendar export | Settings, unchanged |
| Reflection sheet after a session | unchanged |
| Profile setup dialog | unchanged |
| `/timer` screen, `/alarms` screen | no entry point (none exists today); removed as dead code in the shell task |
| Connections feature | stays hidden |
| GPA (Gradus) | Study root row "GPA" |
| Events, Marketplace (Muto), Piano room (Clavis) | Campus root rows |
| News | Home section, and the "News" screen behind "All" |

---

## 4. Screen layouts

Vertical order is exact. Paddings follow section 2.3.

### 4.1 Home

```
NumerShellHeader   title: streak widget         actions: avatar
[offline line]     meta text, only when offline or sync failed
[ActiveSessionBar] only while a session runs (existing widget)

Section "Today"
  Block
    Row  Study     value: time studied today   subtitle: goal progress, if goals are on   -> Study tab
    Row  Habits    value: "3 of 5"                                                         -> Habits tab
  Primary button (full width, one of):
    "Continue <course name>"   a last-used course exists      -> that course's time sheet
    "Start session"            courses exist, none used yet   -> course picker sheet
    "Add course"               no courses                     -> add course sheet
    (hidden while a session runs)

Section "Upcoming"            hidden when empty
  Block, up to 3 rows
    Row  leading icon by kind, title, meta "Today, 18:00"    -> the module screen

Section "News"   trailing text action "All"
  up to 5 news rows, separated by dividers, no block
```

- The Habits row is hidden when the user has no habits.
- "Upcoming" reads a local store only. Kinds and icons: piano booking `piano_outlined`, event
  reminder `event_outlined`. Past items disappear.
- Pull to refresh runs a sync pull and a feed refresh.
- Home makes no module network call and creates no module object.

### 4.2 News row and News screen

A news row:

```
title            rowTitle, at most 2 lines
meta line        meta: source, then date
```

- Meta for an announcement: `NUmer, Nov 27`. For an event: `Event, Dec 12, 18:00, Block C3`
  (kind, date, time, place; parts joined by a comma and a space; missing parts dropped).
- A pinned announcement shows the status label "Pinned" in `primary` at the start of the
  meta line. No other label.
- No images in feed rows.
- Tap: an announcement opens the announcement screen (title as `screenTitle` in the app bar,
  date as `meta`, body as `body`, text only). An event opens the Events module at that event
  when the module is visible; otherwise an event detail built from the feed item.
- The "News" screen is the same rows in one list, newest first, pinned on top, at most 30,
  no pagination, scroll position restored on return.
- When a refresh fails and a cached feed exists, show the cache and one `meta` line above
  the first row: "Updated 10 min ago".

### 4.3 Study

```
NumerShellHeader   title: "Study"    actions: add course (Icons.add, tooltip "Add course"), avatar
[ActiveSessionBar]

Section "Courses"
  the existing course list (rows, reorder, swipe to delete, goal bar)
  empty: "No courses yet." and the button "Add course"

Section "More"
  Block
    Row  Statistics        -> Statistics screen
    Row  History           -> History screen
    Row  Course analysis   status label: "Coming soon"   -> coming-soon screen
    Row  <study modules from the registry, for example GPA>
```

The "Course analysis" row is shown only when at least one course exists.

### 4.4 Campus

```
NumerShellHeader   title: "Campus"    actions: avatar

Block
  Row per visible campus module:  leading icon, title, one-line subtitle, chevron
```

- Subtitles are plain descriptions of what you do there: "Events on campus", "Buy and sell
  between students", "Book the practice room".
- Row order is the registry order: Events, Marketplace, Piano room.
- When there are more than eight rows, add a search field above the block. Not before.

### 4.5 Settings

The existing Settings content and order (identity, profile, appearance, accent colour,
language, week start, display options, switches, export, delete account), reached from the
avatar as a pushed screen. One section is added at the end, before "Delete account":

```
Section "About"
  Block
    Row  Privacy policy    -> opens the policy
    Row  Contact support   -> opens the mail app to the support address
    Row  Version           value: "2.0.0 (45)"
```

---

## 5. Components

All in `packages/numer_ui/lib/src/components/`. Use these; do not build look-alikes.

### 5.1 `NumerSection`

A `sectionTitle` at the left and at most one text action at the right (`TextButton`, one
word, for example "All"). 8 below the title. 24 above the next section.

### 5.2 `NumerBlock`

A container for a group of rows: fill `surfaceContainerHighest`, radius `lg`, no border, no
shadow, no inner padding (rows carry their own). Rows inside are separated by a 1 px
`outlineVariant` divider inset 16 from the left. A block never contains another block, a
card, or a text field.

### 5.3 `NumerRow`

| Part | Spec |
|---|---|
| Height | at least 56 with one line, at least 72 with two; grows with text |
| Padding | 16 left and right |
| Leading (optional) | an icon (24, `onSurfaceVariant`), or an avatar (40), or a data dot (10). 12 to the text |
| Title | `rowTitle`, at most 2 lines |
| Subtitle (optional) | `meta`, 1 line |
| Trailing (at most one) | a value (`body` in `onSurfaceVariant`), a chevron (`chevron_right`, 20) only when the row navigates, a `Switch`, or a status label |

A value and a chevron may appear together only on a navigating row that also shows its
current value. The whole row is the tap target.

### 5.4 Buttons

Three kinds only.

| Kind | Widget | Use |
|---|---|---|
| Primary | `FilledButton` | the one main action of a screen or sheet |
| Secondary | `FilledButton.tonal` | an alternative of equal weight |
| Text | `TextButton` | dismiss, minor actions, the action of an empty state |

- Height 48, radius `md`, label in sentence case and starting with a verb.
- Full width at the bottom of sheets and forms; intrinsic width inline.
- Destructive: the same widgets with `error` as the fill or text colour, only inside a
  confirm sheet.
- Loading (owner rule): the label disappears and only a spinner shows, centred, about the
  label's height (20 pt, stroke 2, in the label colour); the button keeps its size because the
  label stays in the layout invisibly, and it is disabled. Screen readers still hear the label
  plus "loading". This is the only place a spinner is allowed. The button's child is
  `NumerButtonChild(label: ..., loading: ...)`, which draws that.
- No `OutlinedButton`, no `ElevatedButton` in new UI.

### 5.5 Inputs and choices

- Text field: filled, fill `surfaceContainerHighest`, radius `md`, no outline, floating
  label, height 56, helper and error text below in `meta` (`error` colour for errors).
- A choice among 2 to 4 modes: Material `SegmentedButton`.
- A choice among more options: a row showing the current value that opens a sheet with a
  list.
- Never `ChoiceChip`, `FilterChip`, `InputChip`, `ActionChip` or `Chip`.
- On and off: `Switch` as the trailing of a row.
- `NumerOtpField`: six boxes (48 wide, 56 high, radius `md`, fill
  `surfaceContainerHighest`, digit in `sectionTitle`) drawn over one hidden `TextField`
  with `AutofillHints.oneTimeCode`, a digits-only formatter capped at 6, numeric keyboard.
  The focused box has a 2 px `primary` border; in the error state all boxes have a 2 px
  `error` border, the field clears and refocuses. It accepts a pasted code. Semantics label
  from the caller. Calls `onCompleted` at six digits.

### 5.6 Floating action

At most one per screen: `FloatingActionButton.extended`, elevation 0, fill
`primaryContainer`, an icon and a verb label ("New listing"). Bottom right. It hides on
scroll down and returns on scroll up. Identical on iOS and Android. It replaces the glass
action pills.

### 5.7 Sheets

`showNumerSheet`: background `surfaceContainerLow`, top radius `xl`, a drag handle, a title
in `sectionTitle`, content padding 16, the primary button pinned at the bottom above the
safe area. It opens on the root navigator.

`showNumerConfirm`: a sheet with a one-sentence title, at most one sentence of `body`, a
primary or destructive button, and a text button "Cancel". Use it for every confirmation.
`AlertDialog` is reserved for operating-system permission rationales.

**Focus mode (owner rule, every sheet or dialog with a text field).** While the keyboard is up,
the sheet keeps only the active field: its label and the field. Everything else (title,
helper text, other fields, gaps, secondary actions) folds away, and the sheet's actions are
replaced by one primary button, "Done" (or the form's own submit when only one field
exists). Done dismisses the keyboard and the whole form returns. Folding and the button swap
share one 240 ms ease-out animation; with reduce-motion they switch instantly. The keyboard
signal is `MediaQuery.viewInsets.bottom > 0`, not focus alone. "Next" on the keyboard moves to
the next field and opens its fold. Built from `NumerSheetFocusMode`, `NumerFocusFold`,
`NumerFocusGap` and `NumerFocusActions` (ported from Gradus `focus_mode.dart`, which took
it from Muto, so all of the owner's apps behave alike).

### 5.8 Status label

Plain text in `status` style. No pill, no background, no border. Colours: neutral
`onSurfaceVariant`, positive `success`, caution `warning`, negative `error`, highlighted
`primary`. At most one per item. No clusters of labels, tags or badges anywhere.

### 5.9 Toast

`showNumerMessage(context, text, {isError, action})`: the existing floating message
(4 seconds, radius `lg`), moved into `numer_ui`. Used for a short confirmation or a
recoverable error. One sentence. No raw `SnackBar`.

### 5.10 Images

- In a row: 56 by 56, radius `sm`. In a detail header: full width, radius `lg`.
- Always decoded at display size (`cacheWidth`).
- Placeholder and error: a `surfaceContainerHighest` box with no icon.
- A two-column photo grid is allowed only for marketplace listings, because the photo is the
  content.

### 5.11 Avatar

The existing avatar rendering, sizes 32 (header), 40 (rows), 48 (profile).

---

## 6. States

Every screen that loads data ships all four states. A widget test covers each.

| State | Rule |
|---|---|
| Loading | Show cached content if any exists. Otherwise show nothing for the first 300 ms, then `NumerSkeleton`. Never a full-screen or centred spinner |
| Empty | One plain sentence in `body`, `onSurfaceVariant`, centred, 32 below the header, plus one action (a text or primary button). No illustration, no large icon |
| Error | One sentence that names what failed, and "Retry". Same layout as empty |
| Offline | Keep showing what is cached and keep local actions working. Say it once, in `meta` text, not in a banner that pushes content |

`NumerSkeleton`: static boxes in `onSurface` at alpha 0.08, radius `sm`, laid out like the
real rows (a title line 16 high at 60% width, a meta line 12 high at 35% width, the same row
height). No shimmer, no pulse, no gradient.

Do not show an empty state while loading. Do not show a skeleton for a load that finishes
within 300 ms.

Optimistic updates: a simple local action (check a habit, save a favourite, reorder) changes
the screen at once and reverts with a toast if it fails. Bookings, payments and anything
irreversible wait for the server and show the button's loading state.

---

## 7. Motion and haptics

### 7.1 Motion

From `NumerMotion`:

| Token | Duration | Use |
|---|---|---|
| `fast` | 150 ms | press feedback, fades, small state changes |
| `base` | 200 ms | switching content in place, expanding and collapsing |
| `slow` | 250 ms | a large element moving, the theme change |

- Curves: `Curves.easeOutCubic` for entering and moving, `Curves.easeInCubic` for leaving.
- Page transitions are the platform defaults. Do not write custom route transitions.
- Motion exists only to show a change of state. No entrance animation on load, no staggered
  lists, no looping animation, no parallax.
- Reduce motion: get durations through `NumerMotion.of(context, token)`, which returns
  `Duration.zero` when `MediaQuery.disableAnimationsOf(context)` is true.
- Lists use `ListView.builder` or slivers. An animating element sits in a `RepaintBoundary`.
  No `Opacity` widget around large subtrees; use `AnimatedOpacity` or `FadeTransition`.
- The existing iOS tab bar timings (220 ms and 180 ms) stay.

### 7.2 Haptics

| Call | When |
|---|---|
| `HapticFeedback.lightImpact()` | a confirmation the user worked for: session saved, habit checked, booking made, code accepted, listing published |
| `HapticFeedback.selectionClick()` | moving through a picker or a segmented control |
| none | navigation, tab changes, errors, opening sheets |

At most one haptic per user action.

---

## 8. Copy

Applies to EN, RU and KK equally. Strings live in ARB files; nothing user-facing is written
in Dart.

### 8.1 Rules

1. Sentence case everywhere. Only the first word and proper names are capitalised.
2. A button is a verb, or a verb and its object. At most three words.
3. Say the specific thing: the object, the number, the time. No vague praise.
4. No exclamation marks. The one exception is a streak or goal celebration that exists
   today.
5. Banned characters in UI strings: the em dash (U+2014), the en dash (U+2013), the middle
   dot (U+00B7), the bullet (U+2022), the hash sign used as a tag. Join parts with a comma
   and a space, or put them on separate lines. Ranges are written with "to" in the language
   of the string.
6. No trailing ellipsis on labels or progress text. The ellipsis exists only where the
   system truncates.
7. Banned words (EN, and their equivalents in RU and KK): unlock, supercharge, seamless,
   elevate, dive in, journey, effortless, magic, powerful, smart, awesome, oops, whoops.
8. No hashtags, no tag lists, no emoji.
9. AI output is labelled "Generated by AI", as plain text next to the output.
10. Errors say what failed and what to do. They never blame the user and never show a code
    or a server message.
11. Time is written in 24-hour form in all three languages. Dates use the locale's short
    form through `intl` (`DateFormat.MMMd(locale)`), never a hand-built string.
12. Durations: "1 h 20 min", "45 s". Units are localised in the ARB string.
13. RU and KK are written for a native reader, not translated word for word. Reuse the terms
    already in `lib/l10n/app_ru.arb` and `app_kk.arb` for existing concepts (session, course,
    habit, group); do not coin a second word for the same thing.
14. Plurals use ICU plural syntax in the ARB file.

### 8.2 Examples

Use these as the model. If an existing ARB term differs, the existing term wins.

| Where | EN | RU | KK |
|---|---|---|---|
| Empty feed | No news yet. | Новостей пока нет. | Әзірге жаңалық жоқ. |
| Empty feed action | Refresh | Обновить | Жаңарту |
| Empty courses | No courses yet. | Курсов пока нет. | Әзірге курс жоқ. |
| Habits summary | 3 of 5 done | 3 из 5 выполнено | 5-тен 3 орындалды |
| Stale feed | Updated 10 min ago | Обновлено 10 мин назад | 10 мин бұрын жаңартылды |
| Code screen subtitle | We sent a 6-digit code to a.student@nu.edu.kz | Мы отправили 6-значный код на a.student@nu.edu.kz | a.student@nu.edu.kz мекенжайына 6 таңбалы код жібердік |
| Wrong code | Wrong code. 4 attempts left. (plural form in the ARB string) | Неверный код. Осталось попыток: 4. | Код қате. 4 мүмкіндік қалды. |
| Expired code | Code expired. Request a new one. | Код устарел. Запросите новый. | Кодтың мерзімі өтті. Жаңасын сұраңыз. |
| Resend timer | Resend code in 45 s | Отправить снова через 45 с | 45 с кейін қайта жіберу |
| Offline | No connection. Your changes are saved on this device. | Нет соединения. Изменения сохранены на устройстве. | Байланыс жоқ. Өзгерістер құрылғыда сақталды. |
| Load error | Could not load events. | Не удалось загрузить события. | Іс-шараларды жүктеу мүмкін болмады. |
| Retry | Retry | Повторить | Қайталау |
| Booking confirmed | Booked for 18:00 | Забронировано на 18:00 | 18:00-ге брондалды |
| Confirm delete title | Delete this course? | Удалить этот курс? | Бұл курсты жою керек пе? |
| Confirm delete body | Its sessions stay in your history. | Занятия останутся в истории. | Сабақтар тарихта қалады. |
| AI label | Generated by AI | Создано ИИ | ЖИ жасаған |
| Event meta | Event, Dec 12, 18:00, Block C3 | Событие, 12 дек., 18:00, блок C3 | Іс-шара, 12 жел., 18:00, C3 блогы |

Wrong, and why:

| Wrong | Why | Right |
|---|---|---|
| Oops, something went wrong | says nothing, banned word | Could not load events. |
| Unlock your study journey | filler | (no such string) |
| Great job | vague praise | Session saved, 45 min |
| OK | not a verb for the action | Delete course |
| Loading | a label where a skeleton belongs | (no string) |

### 8.3 Mechanical check

`scripts/check_copy.sh` (part of `./scripts/verify.sh`) fails when any value in
`lib/l10n/app_*.arb` or a module's ARB files contains a banned character from rule 5, an
exclamation mark not listed in `scripts/copy_allow.txt`, or a banned EN word from rule 7.
It also fails when the three ARB files of a package do not have the same keys.

---

## 9. Modules: how `app_ui` maps onto this

Modules import `numer_ui`, which keeps their familiar names as a compatibility layer and
resolves them to the tokens above. Module code may keep using the compatibility names; new
module code uses the `Numer*` names.

### 9.1 Colours

| `app_ui` name | Resolves to |
|---|---|
| `AppColors.primary`, `primaryDark`, `primaryAccentDark` | `colorScheme.primary` |
| `primaryLight`, `primaryLightDark` | `colorScheme.primaryContainer` |
| `background` | `colorScheme.surface` |
| `surface`, `surfaceDark`, `fieldBackground`, `serviceBackground`, `balanceCardBackground` | `colorScheme.surfaceContainerHighest` |
| `textPrimary`, `textPrimaryDark`, `textColor`, `textColorDark` | `colorScheme.onSurface` |
| `textSecondary`, `iconGrey` | `colorScheme.onSurfaceVariant` |
| `textDisabled` | `onSurface` at alpha 0.38 |
| `borderGrey`, `borderDark`, `divider`, `dividerColor` | `colorScheme.outlineVariant` |
| `success`, `lightGreen` | `NumerColors.success` |
| `warning` | `NumerColors.warning` |
| `error`, `errorText`, `errorTextDark` | `colorScheme.error` |
| `info`, `lightBlue`, `socialTelegram` | `colorScheme.primary` for text and links; `onSurfaceVariant` for a brand icon |
| `primaryGradient`, `goldGradient`, `gold` | removed; use the flat role of the element |
| `grey`, `iconSecondary` | `colorScheme.onSurfaceVariant` |
| `iconPrimary`, `black` | `colorScheme.onSurface` |
| `iconDisabled` | `onSurface` at alpha 0.38 |
| `white` | `colorScheme.onPrimary` |
| `lightGrey` | `colorScheme.outlineVariant` |
| `transparent` | `Colors.transparent` |
| `orange` | `NumerColors.warning` |
| `green` | `NumerColors.success` |
| `blue` | `colorScheme.primary` |
| `blueLight`, `infoLight` | `colorScheme.primaryContainer` |
| `errorLight` | `colorScheme.errorContainer` |
| `successLight`, `warningLight` | `colorScheme.surfaceContainerHighest` |
| `socialWhatsapp` | `colorScheme.onSurfaceVariant` |

Because scheme colours need a `BuildContext`, the compatibility layer exposes them as
`AppColors.of(context).primary`. Static brand constants are deleted; the call sites change.
Code that branched on `isLight ? X : XDark` reads the single role instead.

### 9.2 Spacing, radii, shadows, type

| `app_ui` name | Resolves to |
|---|---|
| `AppSpacing` values on the 4 pt grid | the equal `NumerSpace` value |
| `AppSpacing.df`, `screenPadding`, `screenHorizontal`, `cardPadding` | `NumerSpace.lg` (16) |
| any `AppSpacing` value off the grid | the nearest lower grid value |
| `radiusSm`, `radiusMd`, `radiusDf`, `radiusLg` | `NumerRadius.sm`, `md`, `lg`, `xl` |
| `HomeRadius.card`, `cardBR`, `cardLg` | `NumerRadius.lg` |
| `HomeRadius.button` | `NumerRadius.md` |
| `HomeRadius.pill` | `NumerRadius.full` |
| `HomeSpacing.*` | the nearest `NumerSpace` value; the class is deleted |
| `AppShadows.*`, `HomeShadows.*` | no shadow |
| `AppSpacing.appBarHeight` | `kToolbarHeight` |
| `AppTextStyles` at 22 and above | `screenTitle` |
| `AppTextStyles` at 16 to 20, semibold or bold | `sectionTitle` |
| `AppTextStyles` at 15 or 16, regular or medium | `rowTitle` |
| `AppTextStyles` at 14 | `body` |
| `AppTextStyles` at 13 and below | `meta` |
| button and label styles | the button's own theme |
| `fontFamily: 'Geist'` | removed |
| the no-splash ripple override | removed; Material's default ripple |

### 9.3 Icons

`AppIcons` keeps its names and returns Material glyphs. The mapping is by meaning, outlined
variant. Names known to be in use:

| `AppIcons` | Material |
|---|---|
| `add` | `Icons.add` |
| `back` | `Icons.arrow_back` |
| `check` | `Icons.check` |
| `close` | `Icons.close` |
| `chevronLeft`, `chevronRight`, `chevronDown` | `chevron_left`, `chevron_right`, `expand_more` |
| `edit` | `Icons.edit_outlined` |
| `warning` | `Icons.warning_amber_outlined` |
| `clockHours` | `Icons.schedule_outlined` |
| `flag` | `Icons.flag_outlined` |
| `heartBroken` | `Icons.heart_broken_outlined` |
| `layoutGrid`, `layoutRows` | `Icons.grid_view_outlined`, `Icons.view_agenda_outlined` |
| `visibilityClosing` | `Icons.visibility_off_outlined` |
| `telegram` | `Icons.send_outlined`, always next to the word "Telegram" |
| `whatsapp` | `Icons.chat_outlined`, always next to the word "WhatsApp" |
| `logo`, `token`, `bonus`, `points` | deleted (they pointed at files that do not exist) |

Every other `AppIcons` entry is mapped the same way in the `numer_ui` task; an entry with no
Material equivalent and no call site is deleted.

### 9.4 Widgets

| `app_ui` widget | Becomes |
|---|---|
| `AppPrimaryButton`, `AppSecondaryButton`, `AppTextButton` | the three buttons of 5.4; the custom colour parameters are removed, except `error` for destructive actions |
| `AppIconButton` | `IconButton` with a required tooltip |
| `AppCard` | `NumerBlock` |
| `AppListTile` | `NumerRow` |
| `AppTextField`, `AppSearchBar` | the text field of 5.5; the search bar keeps its clear and filter tooltips |
| `AppBottomSheet` | `showNumerSheet`, with the safe-area padding of the Gradus line and the root navigator of the Muto line |
| `AppToast`, `ToastManager` | `showNumerMessage` |
| `AppLoader` | a skeleton for pages and lists; the button's own loading state for actions |
| `AppProgressBar`, `AppStepProgress` | `LinearProgressIndicator` with `primary` on `surfaceContainerHighest`, radius `full` |
| `AppAppBar`, `AppSimpleAppBar`, `AppSliverAppBar` | the app bars of section 3, keeping `toolbarHeight` |
| `AppMenu` | Material `MenuAnchor` with the sheet background role |
| `AppCalendar`, `AppCalendarEvent` | stay in the Events package, restyled with tokens |
| `AppOtpField` | `NumerOtpField` |
| bank, user and job cards, premium dialog, level ring, reward toasts, password and phone fields | deleted |

### 9.5 Per module

| Module | Specific changes |
|---|---|
| Gradus | uses `GradusChrome.host`; its screen sits in `NumerModuleScaffold` titled "GPA"; the summary number is the screen's one `display` text |
| Clavis | its nested navigator stays inside `NumerModuleScaffold` titled "Piano room"; week switcher uses icon buttons with tooltips; slots are rows, a free slot's action is a text button "Book"; a made booking gives a light haptic and writes an "Upcoming" item |
| Events | its bottom bar is replaced by tabs "Events", "My requests", and for coordinators "Requests" and "Analytics"; category and sort filters become rows that open sheets; strings move to ARB with key parity; the session-expired text names NUmer and is localised |
| Muto | its bottom bar is replaced by tabs "Browse", "Favorites", "My listings", and for operators "Reports"; "New listing" is the floating action; listing photos may use the two-column grid; contact channels are rows with a generic icon and the channel name; block and report are rows in the seller and listing menus |

---

## 10. Performance budgets

| Budget | Value | How it is checked |
|---|---|---|
| Cold start to first frame of the shell | at most 10% above the baseline recorded in P0-14 | `startup_metrics.dart`, profile build, the reference Android device |
| Effect of enabling a module on cold start | none | the same measurement with the module flag on and off |
| Frame time while scrolling Home, News, a module list | 99th percentile of build plus raster at most 16 ms | `addTimingsCallback`, profile build |
| Work at startup per module | zero network calls, zero storage reads, no controller created | a widget test with counting fakes |
| Download size per module | at most 1.0 MB added to the arm64 release | `flutter build apk --analyze-size` before and after |
| Reaction to a tap | visible within 100 ms | review; optimistic update or the button's loading state |
| A wait longer than 1 s | shows a skeleton or cached content | section 6 |

---

## 11. Banned patterns and the mechanical checks

`scripts/check_design.sh` (part of `./scripts/verify.sh`) counts each pattern below per file
under `lib/` and `packages/`, and compares the counts with `scripts/design_baseline.txt`.
It fails when a count rises or a new file contains a pattern. The baseline may only shrink.

| Pattern | Banned because | Allowed where |
|---|---|---|
| `LinearGradient`, `RadialGradient`, `SweepGradient` | decorative gradients | the colour picker's hue control; the iOS tab bar highlight |
| `BackdropFilter`, `ImageFilter.blur` | glass | the iOS tab bar |
| `BoxShadow`, `elevation:` above 0 | flat surfaces | the iOS tab bar highlight; the toast |
| `Chip(`, `ChoiceChip`, `FilterChip`, `InputChip`, `ActionChip`, `Badge(` | no chips or badge clusters | nowhere |
| `Colors.` other than `Colors.transparent`; `Color(0x` | colours come from roles | `numer_ui` tokens, the avatar catalogue, user colour presets |
| `TextStyle(`, `fontSize:`, `fontFamily:`, `GoogleFonts` | one type scale, system font | `numer_ui` tokens; icon data `fontFamily` for stored habit icons |
| `FontWeight.w600`, `w800`, `w900` | three weights | nowhere in new code |
| `CircularProgressIndicator` | skeletons and cached content instead | inside the button loading state in `numer_ui` |
| `SnackBar(` | one toast | `numer_ui` |
| `AlertDialog(` | confirm sheets | permission rationales |
| `OutlinedButton`, `ElevatedButton` | three button kinds | nowhere in new code |
| `MdiIcons`, `PhosphorIcons`, `FontAwesomeIcons`, `LucideIcons`, `SimpleIcons` | one icon family | the avatar catalogue |
| `withOpacity(` | one alpha API | nowhere |
| `Opacity(` | repaint cost | nowhere in new code |
| `debugPrint(`, `print(` | no leftovers | nowhere in new code |

Things a script cannot count, checked in review against the screenshots:

- more than one filled button or one `display` text on a screen;
- a container inside a container;
- three equal tiles in a row; a decorative illustration; an icon in a coloured circle;
- a row with more than one status label;
- an entrance animation;
- a coloured side stripe.

---

## 12. What a UI task must deliver

1. Screenshots of every screen and sheet it adds or changes: light and dark, in EN and RU.
   Add KK for any screen whose labels are long. Add one screenshot at text scale 1.3.
2. For a screen that loads data: screenshots of loading (skeleton), empty and error.
3. A widget test per state from section 6.
4. `./scripts/verify.sh` passing, which includes `check_design.sh` and `check_copy.sh`.
5. A line in its report for each item of the review list in section 11, answered yes or no.
6. No new token, component, colour, radius, icon package or font. If the task seems to need
   one, stop and ask.
