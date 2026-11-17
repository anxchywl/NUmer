# P3-14: Split `stats.dart` (no behaviour change)

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-12

## Goal
Break the 3228-line `lib/features/stats/screens/stats.dart` into files under the size limit
(D-33), so P3-12 can edit its chips and cards in a file an executor can read. Nothing a user
can see or do changes.

## Read first
- `AGENTS.md` ("Repository Layout", "Size", "Comment style")
- `docs/numer2/DECISIONS.md` D-33
- `lib/features/stats/screens/stats.dart` (all of it), `lib/features/stats/stats.dart` (barrel)
- `scripts/check_file_size.sh`, `scripts/file_size_baseline.txt`,
  `test/boundaries/allowlist.txt`, `scripts/design_baseline.txt`
- `prompts/P3-04-split-home.md` (the same kind of split; its base-class and `part` mixin
  pattern applies here)

## Context
- Line numbers are from `main` at `862c4c2`. If the file changed, find each piece by name.
- What `stats.dart` holds, by line:

  | Lines | Piece |
  |---|---|
  | 22-27 | `StatsScreen` |
  | 28-312 | `_StatsScreenState`: fields, day and range navigation (34-150), `initState`, `dispose`, habit stats loading (174-312) |
  | 313-983 | `build`: header (342), day statistics section (351-498), period statistics section (499-858), heatmap section (859-968), habit statistics section (969-983) |
  | 984-1038 | `_buildSectionContainer` |
  | 1039-1242 | `_loadPieForDay`, `_loadBucketsForRange` (data) |
  | 1243-1329 | `_xLabel`, `_periodLabel`, `_tooltipTitle`, `_buildTooltipDetails` |
  | 1330-1599 | `_buildHabitStatistics`, `_buildHabitLayout`, `_buildStatRow`, `_buildStatCard` |
  | 1600-2205 | the habit report download sheet: `_showDownloadBottomSheet`, `_buildSelectionView`, `_buildSuccessView`, `_generateFile` |
  | 2206-2216 | `_extractLocal` |
  | 2217-2341 | `_ChartWithTooltipOverlay`, `_TooltipBubble` |
  | 2342-2600 | `_StatsBlock`, `_DetailStatCard`, `_SegChip` |
  | 2601-2871 | `_PieChartWithTooltip`, `_FadeInTooltipCard` |
  | 2872-2950 | data classes `_SliceTooltip`, `_Bucket`, `_BucketTooltip`, `_TooltipItem`, `_Slice`, `_PiePayload`, `_BucketsPayload`, enums `_Range`, `_TimeUnit` |
  | 2951-3002 | `_TooltipLayoutDelegate` |
  | 3003-3215 | top-level format helpers (`_pickUnit` to `_nextLabel`) |
  | 3216-3228 | `_HabitStatsResult` |

- `stats.dart` imports `habit_service.dart`, `export_service.dart`, `course.dart`,
  `habit.dart` and `history.dart` past their barrels; those five lines are in
  `test/boundaries/allowlist.txt`. New files import other features through their barrels,
  and the five lines go.
- The design baseline is keyed by path: moved code moves its counts; the per-pattern totals
  must not rise.

## Steps
1. Record the design totals as in P3-04 step 1.
2. Keep `StatsScreen` and its state at `lib/features/stats/screens/stats.dart` (so its size
   baseline entry is lowered, not replaced). Move, with only the renames needed to make a
   private name visible to the file that now holds it (drop the leading underscore and
   keep the name otherwise):
   - `lib/features/stats/models/stats_models.dart`: the data classes, the two enums and
     `_HabitStatsResult`.
   - `lib/features/stats/stats_format.dart`: the format helpers 3003-3215.
   - `lib/features/stats/data/stats_loader.dart`: `_loadPieForDay`, `_loadBucketsForRange`,
     `_buildAnimatedGroups` (1145), `_rangeBounds` (1213), the label helpers 1243-1329 when
     they do not call `setState`, and the habit stats computation (`_computeHabitStats`, 195-312) as top-level functions
     that take what they read today (`AppState`, the course list, dates) as parameters. A
     method that calls `setState` stays in the state.
   - `lib/features/stats/widgets/`: `chart_tooltip.dart` (`_extractLocal`,
     `_ChartWithTooltipOverlay`, `_TooltipBubble`, `_TooltipLayoutDelegate`),
     `stats_block.dart` (`_StatsBlock`, `_DetailStatCard`, `_SegChip`),
     `pie_chart_with_tooltip.dart` (`_PieChartWithTooltip`, `_FadeInTooltipCard`),
     `stats_section_container.dart` (`_buildSectionContainer` as a widget),
     `habit_statistics.dart` (1330-1599 as a widget taking the loaded stats),
     `habit_report_sheet.dart` (1600-2205; `showHabitReportSheet(context, ...)` with the
     parameters it reads), and one widget per `build` section: `day_stats_section.dart`,
     `period_stats_section.dart`, `heatmap_section.dart`. A section widget takes the values
     and callbacks it uses (`_prevDay`, `_setRange`, the futures) through its constructor and
     never sees the state object. A file that still passes 400 lines is split again by the
     visual parts it draws.
   - If the state itself stays above 400 lines, apply P3-04's pattern: an abstract base
     class holding the fields, and a `part` mixin `on` that base holding the navigation and
     loading methods.
3. `build` of `_StatsScreenState` lists the sections and stays under about 60 lines.
4. Barrel `lib/features/stats/stats.dart` keeps its exports; the new files are internal to
   the feature unless another feature imported the moved code (none does today).
5. `test/boundaries/allowlist.txt`: remove the five `stats.dart` lines; add none.
   `scripts/file_size_baseline.txt`: lower the `stats.dart` entry to its new size, or remove
   it when the file is under 400; add no line.
6. `dart run scripts/check_design.dart --write-baseline`; compare totals (no total rises).
7. Add `test/features/stats/stats_format_test.dart` covering `fmtHMS`, `pickUnit`,
   `niceInterval` and `fmtTotalVerbose` for a few values (characterisation: assert what the
   moved code returns today).
8. Run `./scripts/verify.sh`. Report `wc -l` of every file under `lib/features/stats/`.

## Non-goals
- No redesign, no string, colour or duration change, no fixed bug (P3-12 changes the chips,
  shadow and Kazakh font branches). A bug you notice goes in the report.
- Do not change `heatmap_calendar.dart`, `heatmap_service.dart` or any other feature.

## Constraints
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`; this task adds none and moves hard-coded ones as they are.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji. Existing comments move with their code unchanged.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. `scripts/check_file_size.sh` (in `verify.sh`) enforces it. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit; when it is split away, remove its entry. Never add a new path to the baseline.
- No unrequested features, abstractions, dependencies or error handling.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0, including the boundary, design and size checks.
- [ ] Every new file is under 400 lines; `stats.dart` is under 400 or its baseline entry equals its new size, and the report says which.
- [ ] The allowlist lost the five `stats.dart` lines and gained none; the size baseline gained no line.
- [ ] No design total rises (diff in the report).
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Open Statistics on a device: day, week, month, year, the pie tooltip, the habit report
  download. Everything looks and works as before.

## Deliverable
Branch `numer2/p3-14-split-stats`, one commit, message `refactor: split the statistics screen` (subject line only). Do not push.
Report: files with line counts, the design totals diff, test output, any bug noticed.

## Stop and ask if
- Moving a piece needs a logic change beyond making a name visible and passing values in.
- A widget would need to call a method of the state object instead of a callback.
