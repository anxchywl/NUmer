# P3-09: News on Home and the News screen

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-07, P3-08

## Goal
Show the composed feed (`feed/current`) as the News section of Home and as the News screen
(`DESIGN.md` 4.2), cached on the device so it appears at once and costs one read per
refresh at most every 30 minutes (D-21).

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 4.1, 4.2, 5.1, 5.8, 6, 8 and 12 (binding)
- `docs/numer2/DECISIONS.md` D-21, D-37, D-40
- `functions/src/feed/types.ts` and `compose.ts` (from P3-08: the item shape)
- `lib/core/config/app_config_service.dart` (the cache-first pattern to copy),
  `lib/app/bootstrap.dart:96-102` (`_fetchAppConfig`, a server read) and the provider list
- `lib/features/home/home_screen.dart` (after P3-07)
- `lib/features/ai_analysis/ai_analysis_screen.dart` (a plain pushed screen)

## Context
- `feed/current` is `{items: FeedItem[], composedAt, eventsOk}`. An item: `id`, `kind`
  (`announcement` or `event`), `title` (`{en, ru?, kk?}`; events carry `en` only, "shown as
  written"), `body?` (same shape, announcements only), `startsAt?` and `publishedAt`
  (Firestore `Timestamp`), `place?`, `pinned`, `link?`. Items arrive ranked; the client
  does not reorder them.
- Rules allow a signed-in `get` of `feed/current` only.
- Dates: `intl` 0.20.2 has `en`, `ru` and `kk` date symbols, loaded by
  `GlobalMaterialLocalizations`; pass `l10n.localeName` as the locale (as
  `habit_logging_sheet.dart:510` does).
- The cache is JSON in `SharedPreferences` (Hive is not needed), key `news_feed_v1`:
  `{"fetchedAt": <ms>, "items": [...]}` with timestamps as epoch milliseconds.
- Refresh: at most every 30 minutes unless forced; forced by pull to refresh and by the
  retry and refresh buttons. Home triggers an unforced refresh after its first frame.
- Event taps (D-40): no Events module exists until P4-11. The news feature takes a host
  hook `bool Function(BuildContext context, FeedItem item)` that opens the item in a module
  and returns true, or returns false; the app passes `(_, _) => false` for now, so every
  event opens the event detail built from the feed item.
- Strings (`DESIGN.md` 8.2 where it has the text):

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `newsTitle` | News | Новости | Жаңалықтар |
  | `newsAll` | All | Все | Барлығы |
  | `newsPinned` | Pinned | Закреплено | Бекітілген |
  | `newsEmpty` | No news yet. | Новостей пока нет. | Әзірге жаңалық жоқ. |
  | `newsRefresh` | Refresh | Обновить | Жаңарту |
  | `newsLoadError` | Could not load news. | Не удалось загрузить новости. | Жаңалықтарды жүктеу мүмкін болмады. |
  | `newsUpdatedMinutes(minutes)` | Updated {minutes} min ago | Обновлено {minutes} мин назад | {minutes} мин бұрын жаңартылды |
  | `newsUpdatedHours(hours)` | Updated {hours} h ago | Обновлено {hours} ч назад | {hours} сағ бұрын жаңартылды |
  | `newsSourceNumer` | NUmer | NUmer | NUmer |
  | `newsKindEvent` | Event | Событие | Іс-шара |
  | `newsOpenLink` | Open link | Открыть ссылку | Сілтемені ашу |

  Reuse `retry`.

## Steps
1. `lib/features/news/models/feed_item.dart`: `enum FeedKind { announcement, event }` and
   `@immutable class FeedItem` with the fields of the Context (`DateTime` for the two
   times, `Map<String, String>` for the texts), `factory FeedItem.fromFirestore(Map<String,
   dynamic>)` (reads `Timestamp`), `fromJson` and `toJson` (epoch milliseconds), and
   `String localized(Map<String, String> text, String languageCode)` returning the
   language's text when present and non-empty, else `en`. An item that fails to parse is
   skipped by the list parser, not thrown.
2. `lib/features/news/data/feed_repository.dart`: `class FeedRepository extends
   ChangeNotifier` with `FeedRepository({required SharedPreferences prefs, required
   Future<Map<String, dynamic>?> Function() fetch, DateTime Function() now =
   DateTime.now})`. The constructor reads the cache synchronously (as `AppConfigService`
   does). Public: `List<FeedItem> get items`, `DateTime? get fetchedAt`, `bool get
   lastRefreshFailed`, `bool get isLoading`, `Future<void> refresh({bool force = false})`.
   `refresh` returns at once when a refresh is running, or when not forced and `fetchedAt`
   is less than 30 minutes old; otherwise it calls `fetch` once, on `FirebaseException`
   sets `lastRefreshFailed` and keeps the items, on success replaces items, sets
   `fetchedAt`, clears the flag and writes the cache. A `null` document means no items.
   Notify on each change of the public state.
3. `lib/app/bootstrap.dart`: `_fetchFeed()` reading `feed/current` with `GetOptions(source:
   Source.server)`, like `_fetchAppConfig`; provider `ChangeNotifierProvider<FeedRepository>(
   create: (_) => FeedRepository(prefs: prefs, fetch: _fetchFeed))`.
4. `lib/features/news/widgets/news_row.dart`: `NewsRow({required FeedItem item, required
   VoidCallback onTap})`: `InkWell` > `ConstrainedBox(minHeight: 72)` > `Padding(horizontal:
   NumerSpace.lg, vertical: NumerSpace.sm)` > `Column(crossAxisAlignment: start, mainAxisAlignment:
   center)`: the localized title in `rowTitle` (`maxLines: 2`, ellipsis), `SizedBox(height:
   NumerSpace.xs)`, and a `Row` of, when `item.pinned`, `NumerStatusLabel(l10n.newsPinned,
   tone: NumerStatusTone.highlighted)` and `SizedBox(width: NumerSpace.sm)`, then
   `Expanded(Text(newsMeta(...), style: context.text.meta, maxLines: 1, overflow:
   ellipsis))`. No image, no icon.
5. `lib/features/news/news_meta.dart`: `String newsMeta(AppLocalizations l10n, String locale,
   FeedItem item)`: an announcement gives `'${l10n.newsSourceNumer}, ${DateFormat.MMMd(
   locale).format(publishedAt)}'`; an event gives the parts `l10n.newsKindEvent`,
   `DateFormat.MMMd(locale).format(startsAt)`, `DateFormat.Hm(locale).format(startsAt)`,
   `place`, dropping missing or empty parts, joined by `', '`. Times shown in the device's
   local time zone (`toLocal()`). `String newsUpdatedLine(AppLocalizations l10n, Duration
   age)`: under 60 minutes `newsUpdatedMinutes(max(1, minutes))`, else
   `newsUpdatedHours(hours)`.
6. `lib/features/news/widgets/news_list.dart`: `NewsList({required List<FeedItem> items,
   required int limit, required void Function(FeedItem) onOpen, String? staleLine})` as a
   box widget: the stale line (`meta`, padded `NumerSpace.lg` left and right, `NumerSpace.sm`
   below) when given, then up to `limit` `NewsRow`s with `Divider(height: 1, thickness: 1,
   indent: NumerSpace.lg, color: outlineVariant)` between them. No block around them.
7. `lib/features/news/screens/news_screen.dart`: `NewsScreen({required bool Function(
   BuildContext, FeedItem) openInModule})`: `Scaffold(appBar: AppBar(title:
   Text(l10n.newsTitle)), body: RefreshIndicator(onRefresh: () => repo.refresh(force: true),
   child: ...))` showing the four states of step 9 with a `ListView.builder` (key
   `PageStorageKey('news')`) of all items (at most 30) when there are items.
8. `lib/features/news/screens/announcement_screen.dart`: `AnnouncementScreen(FeedItem
   item)`: `AppBar(title: Text(localized title))`, body a `ListView(padding:
   EdgeInsets.all(NumerSpace.lg))` of the date (`DateFormat.yMMMd(locale)`, `meta`),
   `SizedBox(height: NumerSpace.md)`, the localized body (`body`), and, when `link` is set,
   `SizedBox(height: NumerSpace.md)` and a `TextButton(child: Text(l10n.newsOpenLink))`
   that calls `launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication)` and shows
   `l10n.linkOpenFailed` (from P3-05) with `showAppMessage` when it returns false.
   `lib/features/news/screens/event_detail_screen.dart`: `EventDetailScreen(FeedItem item)`:
   `AppBar(title: Text(item.title['en']!))`, body the meta line of step 5 in `body` style,
   padded `NumerSpace.lg`. Both screens are text only.
9. States, the same on the Home section and on the News screen (`DESIGN.md` 6):
   - items present: the list; when `lastRefreshFailed`, the stale line from `fetchedAt`;
   - no items, loading, no cache: `NumerSkeleton(rows: 3)` (it waits 300 ms itself);
   - no items, last refresh failed, no cache: `NumerErrorState(message: l10n.newsLoadError,
     retryLabel: l10n.retry, onRetry: () => repo.refresh(force: true))`;
   - no items after a successful refresh: `NumerEmptyState(message: l10n.newsEmpty,
     actionLabel: l10n.newsRefresh, onAction: () => repo.refresh(force: true))`.
   Tap: an announcement pushes `AnnouncementScreen`; an event first calls
   `openInModule(context, item)` and, when it returns false, pushes `EventDetailScreen`.
   Push on the root navigator.
10. Home (`home_screen.dart`): after the Today section, `NumerSection(title: l10n.newsTitle,
    actionLabel: l10n.newsAll, onAction: <push NewsScreen>, child: <step 9 with
    NewsList(limit: 5)>)`. `HomeScreen` gains `required bool Function(BuildContext,
    FeedItem) openInModule`, passed on to `NewsScreen`; `shell_tabs.dart` passes `(_, _) =>
    false`. In `initState`, after the first frame, call
    `context.read<FeedRepository>().refresh()`. Pull to refresh runs
    `Future.wait([syncNow(), feed.refresh(force: true)])`.
11. Barrel `lib/features/news/news.dart` exporting the model, repository, `NewsScreen` and
    `NewsList`. Strings: add the table's keys to the three ARB files; run `flutter gen-l10n`.
12. Tests under `test/features/news/`:
    - `feed_repository_test.dart` (counting fake `fetch`, fake clock, mock
      `SharedPreferences`): a cached feed is available before any refresh; a refresh calls
      `fetch` once and replaces the items; a second unforced refresh within 30 minutes makes
      no call; after 30 minutes it makes one; a forced refresh always makes one; a
      `FirebaseException` keeps the items and sets `lastRefreshFailed`; two concurrent
      refreshes make one call; a malformed item is skipped.
    - `feed_item_test.dart`: locale `ru` with a `ru` title returns it; `kk` without one
      returns `en`; round trip through JSON keeps every field.
    - `news_meta_test.dart`: `NUmer, 27 Nov` for an announcement in EN; `Event, 12 Dec, 18:00,
      Block C3` in EN; a missing place is dropped; RU uses the locale's short month;
      `Updated 10 min ago`, `Updated 2 h ago`.
    - `news_section_test.dart` (Home section in isolation, a fake repository): cached then
      fresh (cache shows, then the new items after refresh); stale line with a failed
      refresh and a cache; empty; error without cache; skeleton only after 300 ms; pinned
      label only on pinned items; at most five rows; "All" opens `NewsScreen`; an event tap
      with the hook returning false opens `EventDetailScreen`, returning true pushes
      nothing.
13. Run `./scripts/verify.sh`.
14. Screenshots (`DESIGN.md` 12): Home with news (one pinned), the News screen, an
    announcement, an event detail, the stale line, empty, error and skeleton; light and dark,
    EN and RU; KK for the News screen; one at text scale 1.3. Use a local emulator feed, not
    production.

## Non-goals
- No images in feed items. No pagination. No change to the backend (P3-08).
- No Events module routing beyond the hook (P4-11 fills it). No push notification for news.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`. This feature only reads `feed/current`, through the repository.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (the features list in `AGENTS.md` gains `news`).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The four test files of step 12 exist and pass; the counting fake shows one read per refresh.
- [ ] `grep -rn "Image\.\|CircularProgressIndicator" lib/features/news` prints nothing.
- [ ] Screenshots of step 14 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Publish a test announcement (P3-08's script) on staging and look at it on Home.

## Deliverable
Branch `numer2/p3-09-news-client`, one commit, message `feat: show the news feed on home and the news screen` (subject line only). Do not push.
Report: files changed, test output, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- The item shape written by P3-08 differs from the Context.
