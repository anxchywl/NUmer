# Phase 3 outlines: superapp shell

Outlines, not prompts. Before a task starts, expand it with `TEMPLATE.md`, citing the code as
it is then (phases 0 and 1 will have moved files). Everything here is bound by
`../DESIGN.md`; section numbers refer to it.

Common to every task below:
- Repo NUmer, base `main`, one commit, `./scripts/verify.sh` must pass.
- UI tasks deliver what DESIGN section 12 lists.
- No task adds a colour, radius, text style, icon package, font or dependency.

---

## P3-01 `numer_ui`: theme builder and components
**Depends on:** P1-03. **Executor:** sonnet, high. **Risk:** med.

**Goal:** the package can build NUmer's theme and holds every component of DESIGN section 5.

**Touches:** `packages/numer_ui/lib/src/theme/`, `packages/numer_ui/lib/src/components/`,
`lib/app/app_theme.dart`, `lib/shared/widgets/app_toast.dart`.

**Steps:**
1. `NumerTheme.build({required Color seed, required Brightness brightness})`: Material 3,
   `ColorScheme.fromSeed`, the `NumerColors` extension, the existing switch theme, a filled
   input theme (5.5), button themes (5.4), a bottom sheet theme (5.7), app bar theme (3.2).
   Compare with today's theme first: the only visible differences allowed are the ones
   DESIGN specifies.
2. Components, one file each: `NumerSection`, `NumerBlock`, `NumerRow`, `NumerShellHeader`,
   `NumerModuleScaffold`, `showNumerSheet`, `showNumerConfirm`, `NumerStatusLabel`,
   `NumerSkeleton`, `NumerEmptyState`, `NumerErrorState`, `showNumerMessage`, `NumerFab`.
3. `lib/app/app_theme.dart` calls `NumerTheme.build`. `showAppMessage` becomes a one-line
   forwarder to `showNumerMessage`.

**Acceptance:** a widget test per component for layout facts that DESIGN states as numbers
(row minimum heights, paddings, radii, the skeleton's 300 ms delay, the sheet's top radius);
golden-free; the contrast test still passes; a gallery screen under
`packages/numer_ui/example/` shows every component in both modes for the screenshots.

**Non-goals:** restyling any existing screen; the module compatibility layer (P3-02).

**Stop and ask if:** today's theme has a property DESIGN does not mention and removing it
changes a screen.

---

## P3-02 `numer_ui`: compatibility layer for module code
**Depends on:** P3-01. **Executor:** sonnet, high. **Risk:** med.

**Goal:** module code written against `app_ui` compiles against `numer_ui` with small,
mechanical edits, and renders with NUmer's tokens.

**Inputs:** the four `app_ui` copies (`RESEARCH.md` 8.1). Base on the Gradus copy, add
Clavis's `toolbarHeight`, Muto's sheet `useRootNavigator`, search tooltips and six icons.

**Steps:**
1. `packages/numer_ui/lib/compat.dart` exporting `AppColors.of(context)`, `AppSpacing`,
   `AppTextStyles.of(context)`, `AppIcons`, `AppIcon`, and the widgets of DESIGN 9.4, each
   implemented on top of the P3-01 components and tokens exactly as the tables in DESIGN
   section 9 map them.
2. `AppIcons`: every entry of the Gradus and Muto copies mapped to a Material glyph; an entry
   with no call site in any module and no Material equivalent is dropped. Produce the full
   mapping table in the report.
3. A `MIGRATION.md` in the package: the search-and-replace steps a module performs (import
   path, `AppColors.x` to `AppColors.of(context).x`, removed names and their replacements).
4. Port the Gradus copy's tests that still apply; add a test that the package depends on
   `flutter` only.

**Acceptance:** `grep -rn "lucide\|google_fonts\|flutter_svg\|simple_icons\|Geist"
packages/numer_ui` is empty; the parity test lists every compat name and asserts it exists;
`check_design.sh` passes with the compat files held to the same rules as everything else.

**Non-goals:** editing any module repo (phase 4 does).

**Stop and ask if:** a widget used by a module has behaviour DESIGN forbids (for example a
gradient button) and no mapping row covers it.

---

## P3-03 Module registry, session contract, lazy mount
**Depends on:** P0-13, P3-01. **Executor:** opus, medium. **Risk:** med.

**Goal:** the host has one place that knows which modules exist, whether a user sees them,
and how to open them, without creating anything until a module is opened.

**Touches:** `lib/app/modules/` (new), `lib/core/identity/` (new).

**Steps:**
1. `lib/core/identity/id_token_provider.dart`: `typedef IdTokenProvider = Future<String>
   Function({bool forceRefresh})` and an implementation over `FirebaseAuth`. A helper
   `handleSessionExpired()` forces one refresh and signs out only if that fails.
2. `lib/app/modules/module_descriptor.dart`: `id`, `titleKey`, `subtitleKey`, `icon`,
   `section` (`study` or `campus`), `flagId`, `WidgetBuilder builder`.
3. `lib/app/modules/module_registry.dart`: the list (empty for now) and
   `visibleModules(section, AppConfigService, uid)`.
4. `openModule(context, descriptor)`: pushes `NumerModuleScaffold` on the root navigator;
   the builder runs only then.

**Acceptance:** a test builds the shell with two fake descriptors whose builders count calls:
zero calls until `openModule`; visibility follows the flag rules; a 401 path calls refresh
exactly once.

**Non-goals:** any real module; the tab changes (P3-05).

---

## P3-04 Split `home.dart` (no behaviour change)
**Depends on:** P0-12. **Executor:** sonnet, high. **Risk:** med.

**Goal:** the 2982-line `lib/features/home/home.dart` becomes files that P3-06 and P3-07 can
move around.

**Steps:** move, unchanged, into the features that own them: the course list and course row
to `lib/features/courses/widgets/`; the course time sheet (timer, stopwatch, pomodoro) to
`lib/features/sessions/widgets/`; add and edit course sheets to `lib/features/courses/`; the
active session bar and the auto-finish watcher to `lib/features/sessions/widgets/`; the
streak title and sync chip stay in `home`. Export through barrels. Delete the duplicate
`_IosLiquidActionPill` by keeping one private copy where it is still used (P3-12 removes it).

**Acceptance:** no file above 700 lines among the new ones; `home.dart` under 400; the
boundary allow-list shrinks; no visible change (owner runs the smoke list).

**Non-goals:** any redesign; any behaviour change.

---

## P3-05 New shell: tabs, header avatar, Settings screen, About
**Depends on:** P3-03, P3-04, owner's answer to O-1. **Executor:** sonnet, high. **Risk:** high.

**Goal:** the tab bar is Home, Habits, Study, Groups and (when a campus module is visible)
Campus; Settings opens from the avatar on every tab root.

**Steps:**
1. `lib/app/shell/shell_tabs.dart`: the five destinations of DESIGN 3.1 with the icons and
   labels given there; Campus included only when `visibleModules(campus)` is non-empty.
   Add `navStudy`, `navCampus` (strings in DESIGN 3.1).
2. Every tab root uses `NumerShellHeader` (3.2) with the avatar action. Habits: the
   Progress and List switch moves under the header as a `SegmentedButton`.
3. The Account screen becomes `SettingsScreen`, pushed from the avatar; its content and
   order stay; add the About section of DESIGN 4.5 (privacy URL and support address come from
   the task message; version from `package_info_plus`).
4. Temporary roots so the release is usable: Study shows the existing Statistics screen
   content under the new header until P3-06; Home keeps its current content until P3-07.
5. Delete `/timer`, `/alarms`, `TimerScreen`, `AlarmsScreen` and the alarm code in
   `AppState` only if nothing schedules an alarm (check for stored alarms and local
   notifications first; if users may have alarms, keep the scheduling code and report).
6. Fix the sign-out navigation to a route that exists.
7. The iOS and Android bars read the destination list; no visual change to either bar.

**Acceptance:** widget tests: four tabs with no module visible, five with one; the avatar
opens Settings from each root; `grep -rn "'/timer'\|'/alarms'" lib` is empty; screenshots of
all roots and Settings.

**Non-goals:** Home and Study content (P3-06, P3-07); restyling Settings rows.

**Stop and ask if:** O-1 is unanswered; stored alarms exist for real users.

---

## P3-06 Study root
**Depends on:** P3-05. **Executor:** sonnet, high. **Risk:** med.

**Goal:** Study is the course list with its timer sheet, plus rows for Statistics, History,
Course analysis and study modules (DESIGN 4.3).

**Steps:** build the root from the widgets P3-04 extracted; header action "Add course";
the active session bar on top; section "More" as a `NumerBlock` of `NumerRow`s; registry rows
for `section: study`; the floating add and AI buttons are gone. Strings: `studyCoursesTitle`,
`studyMoreTitle`, `courseAnalysisTitle`, `comingSoon` (EN, RU, KK in DESIGN 8.2 style).

**Acceptance:** widget tests for empty and non-empty course lists and for a registry row
appearing with a flag; reorder and swipe-to-delete still work (existing behaviour test);
screenshots.

**Non-goals:** changing the course row's content or the time sheet.

---

## P3-07 Home: today layout
**Depends on:** P3-06. **Executor:** sonnet, high. **Risk:** med.

**Goal:** Home is DESIGN 4.1: streak header, running session, Today block, one primary
button, Upcoming, News.

**Steps:** Today block rows from `AppState` values that exist (time studied today, goal
progress, habits done today); the primary button logic of 4.1 with `lastCourseId` kept in
`SharedPreferences` when a course sheet starts a session; a course picker sheet; pull to
refresh; placeholders for Upcoming (P3-10) and News (P3-09) that render nothing until those
land. Strings for each label in EN, RU, KK.

**Acceptance:** widget tests for the three button states and for the hidden Habits row; a
test with counting fakes proves Home makes no module call; screenshots including a running
session.

**Non-goals:** the feed and the local store.

---

## P3-08 Feed backend: announcements and the composed feed
**Depends on:** P2-02, P0-06. **Executor:** sonnet, high. **Risk:** med.

**Goal:** `feed/current` exists and is rebuilt every 30 minutes and on publish (D-21).

**Steps:**
1. `functions/src/feed/`: callable `publishAnnouncement({title: {en, ru, kk}, body: {...},
   pinned, expiresAt?})` gated on `numer:editor`; callable `retractAnnouncement({id})`.
2. `composeFeed()`: newest 30 of announcements (not expired) and upcoming events fetched from
   the Events public list URL (parameter `FEED_EVENTS_URL`, optional; absent means
   announcements only); pinned first (at most 2), then by publish time; ended events dropped;
   write one document with `items[]` and `composedAt`. Item shape: `id`, `kind`
   (`announcement` or `event`), `title`, `body?`, `startsAt?`, `place?`, `publishedAt`,
   `pinned`, `link?`.
3. A scheduled function every 30 minutes and a trigger on `announcements` writes both call
   `composeFeed`. An Events fetch failure keeps the previous event items.
4. A script `functions/scripts/publish_announcement.js` for the owner.

**Acceptance:** emulator tests for ordering, the cap of 30, pin limit, ended events dropped,
fetch failure behaviour, role gate; rules tests that clients read `feed/current` and nothing
else; the document stays under 100 KB.

**Stop and ask if:** the Events public list needs authentication or lacks a publish time.

---

## P3-09 News on Home and the News screen
**Depends on:** P3-07, P3-08. **Executor:** sonnet, high. **Risk:** med.

**Goal:** DESIGN 4.2 on screen.

**Steps:** `lib/features/news/` (new feature, barrel): a `FeedRepository` that returns the
cached feed at once (Hive is not needed; cache the JSON in `SharedPreferences`) and refreshes
at most every 30 minutes or on pull to refresh; the news row; the News screen; the
announcement screen; event tap routing through the registry. All four states of DESIGN
section 6.

**Acceptance:** widget tests for cached-then-fresh, stale line, empty, error, pinned label,
locale fallback to EN; one Firestore read per refresh (counting fake); screenshots.

---

## P3-10 Local "Upcoming" store
**Depends on:** P3-07. **Executor:** sonnet, medium. **Risk:** low.

**Goal:** modules can put a personal upcoming item on Home without Home touching them.

**Steps:** `lib/core/upcoming/upcoming_store.dart`: items `{id, moduleId, kind, title,
startsAt, route}` kept in `SharedPreferences` per uid; `put`, `remove`, `watchUpcoming(now)`
dropping past items; Home's Upcoming section reads it; cleared on sign-out.

**Acceptance:** unit tests for expiry, per-user isolation, removal; Home shows at most three,
soonest first.

---

## P3-11 Campus root
**Depends on:** P3-05. **Executor:** sonnet, medium. **Risk:** low.

**Goal:** DESIGN 4.4: one block of rows from the registry.

**Acceptance:** widget tests with zero, one and nine fake modules (search appears only at
nine); screenshots with two fake modules.

---

## P3-12 Design pass: glass, gradients, chips, raw toasts
**Depends on:** P3-05, P3-14, P3-15. **Executor:** sonnet, high. **Risk:** med. May be split per feature.

**Goal:** remove what DESIGN section 11 bans from existing screens, without redesigning them.

**Steps, each mechanical:** glass action pills become `NumerFab`; the gradients on the auth
screen become flat `surface`; `ChoiceChip` period and format selectors become
`SegmentedButton`; the custom segmented pills in Habits and the leaderboard become
`SegmentedButton`; raw `SnackBar` calls become `showNumerMessage`; `AlertDialog`
confirmations become `showNumerConfirm`; centred spinners on list screens become
`NumerSkeleton` with the 300 ms delay; Statistics section cards lose their shadow; the
Kazakh font-size branches in Statistics are removed in favour of wrapping; the sparkle icon
for AI is removed; the hard-coded "Create new" becomes an ARB string.

**Acceptance:** `scripts/design_baseline.txt` shrinks and the report lists the before and
after count per pattern; before and after screenshots of every touched screen in both modes;
no behaviour change.

**Stop and ask if:** a banned pattern carries meaning that a token cannot express.

---

## P3-13 Docs after shell
**Depends on:** P3-12. **Executor:** sonnet, low.

`docs/PRODUCT.md`: the new navigation and news. `AGENTS.md`: `packages/numer_ui`, the module
registry, "how to add a module" replacing "creating a new feature" where they differ, the
rule that UI follows `docs/numer2/DESIGN.md` (move DESIGN to `docs/DESIGN.md` and fix links).
`README.md`: the tree.
