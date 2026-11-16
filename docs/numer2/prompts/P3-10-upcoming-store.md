# P3-10: Local "Upcoming" store

**Recommended model:** sonnet   **Effort:** medium
**Risk:** low   **Est.:** 3 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P3-07

## Goal
Let a module put a personal upcoming item (a piano booking, an event reminder) on Home
without Home loading the module or touching the network (D-21). The store is local and
works offline.

## Read first
- `AGENTS.md`
- `docs/numer2/DESIGN.md` sections 4.1, 5.2, 5.3, 6, 8 and 12 (binding)
- `docs/numer2/DECISIONS.md` D-21, D-40
- `lib/core/config/app_config_service.dart` (a `SharedPreferences`-backed `ChangeNotifier`)
- `lib/features/home/home_screen.dart` (after P3-07, and P3-09 if it has landed)
- `lib/features/account/screens/settings_screen.dart`: the sign-out handler and the
  successful-deletion path
- `lib/app/bootstrap.dart` (provider list)

## Context
- Items are written by module host folders in phase 4 (P4-08 Clavis, P4-11 Events); this
  task builds the store and the Home section, with no writer yet.
- Kinds and icons (`DESIGN.md` 4.1): piano booking `Icons.piano_outlined`, event reminder
  `Icons.event_outlined`.
- Opening an item's module screen goes through a host hook, as in P3-09 (D-40): `bool
  Function(BuildContext context, UpcomingItem item)`. The app passes `(_, _) => false`
  until a module fills it; a row whose hook returns false for every item is drawn without a
  chevron and without `onTap`, so a tap does nothing.
- Storage: `SharedPreferences` key `upcoming_v1_<uid>`, a JSON list. One list per user, so
  a second account on the device never sees the first one's items.
- Strings:

  | Key | EN | RU | KK |
  |---|---|---|---|
  | `upcomingTitle` | Upcoming | Предстоящее | Алдағы |
  | `tomorrow` | Tomorrow | Завтра | Ертең |

  Reuse `today`.

## Steps
1. `lib/core/upcoming/upcoming_item.dart`: `enum UpcomingKind { pianoBooking, eventReminder }`
   (stored by `name`); `@immutable class UpcomingItem` with `String id`, `String moduleId`,
   `UpcomingKind kind`, `String title`, `DateTime startsAt`, `String route`, `toJson` and
   `fromJson` (`startsAt` as epoch milliseconds, UTC). An entry with an unknown kind or a
   missing field is skipped on read.
2. `lib/core/upcoming/upcoming_store.dart`: `class UpcomingStore extends ChangeNotifier` with
   `UpcomingStore(SharedPreferences prefs, {DateTime Function() now = DateTime.now})` and:
   - `List<UpcomingItem> upcoming(String uid)`: the stored items whose `startsAt` is not
     before now, soonest first;
   - `Future<void> put(String uid, UpcomingItem item)`: replaces an item with the same
     `id`, drops past items, writes, notifies;
   - `Future<void> remove(String uid, String id)`: removes, writes, notifies;
   - `Future<void> clear(String uid)`: removes the key, notifies.
   Provide it in `bootstrap.dart`: `ChangeNotifierProvider<UpcomingStore>(create: (_) =>
   UpcomingStore(prefs))`.
3. `lib/features/home/upcoming_section.dart`: `UpcomingSection({required String uid,
   required bool Function(BuildContext, UpcomingItem) openInModule})`. Watches
   `UpcomingStore`; when `upcoming(uid)` is empty it returns `const SizedBox.shrink()` (the
   section is hidden, `DESIGN.md` 4.1). Otherwise `NumerSection(title: l10n.upcomingTitle,
   child: NumerBlock(children: <the first three items as NumerRow(leading: Icon(<icon by
   kind>), title: item.title, subtitle: upcomingWhen(l10n, item.startsAt, DateTime.now()), showChevron:
   canOpen, onTap: canOpen ? ... : null)>))`.
   `String upcomingWhen(AppLocalizations l10n, DateTime startsAt, DateTime now)` in the
   same file: `today` or `tomorrow` when the local date matches, else
   `DateFormat.MMMd(l10n.localeName)`, then `', '`, then `DateFormat.Hm(l10n.localeName)`.
   A widget re-reads the time each build, so a past item disappears on the next rebuild.
4. Home: insert `UpcomingSection(uid: <current uid>, openInModule: widget.openUpcoming)`
   between the Today section and the News section. `HomeScreen` gains `required bool
   Function(BuildContext, UpcomingItem) openUpcoming`; `shell_tabs.dart` passes `(_, _) =>
   false`.
5. Sign-out and deletion: in the Settings sign-out handler, before `authController.signOut()`,
   `await context.read<UpcomingStore>().clear(uid)` with the uid read before the awaits; on
   successful account deletion, the same call before navigating away.
6. Strings: add the two keys; run `flutter gen-l10n`.
7. Tests:
   - `test/core/upcoming/upcoming_store_test.dart` (fake clock, mock prefs): put then
     upcoming returns the item; an item in the past is not returned; `put` with the same id
     replaces; `remove` removes; user `a`'s items are not visible to user `b`; `clear(a)`
     leaves `b`'s items; a malformed stored entry is skipped; order is soonest first.
   - `test/features/home/upcoming_section_test.dart`: empty store, nothing rendered; five
     items, three rows soonest first with the right icons; `Today, 18:00` and `Tomorrow,
     09:30` and a later date in EN, `Сегодня, 18:00` in RU; with the hook returning false
     rows have no chevron.
8. Run `./scripts/verify.sh`.
9. Screenshots (`DESIGN.md` 12): Home with two upcoming items (written by a temporary test
   button or the debugger, not committed), light and dark, EN and RU; one at text scale 1.3.

## Non-goals
- No writer of items (phase 4), no reminders or notifications, no network, no sync of the
  store across devices.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`. This store is device-local by design and is not synced.
- Never renumber a Hive typeId or reorder adapter writes. A new field is an appended write and a guarded read; a new type takes the next free id.
- Every user-facing string goes in `lib/l10n/app_en.arb`, `app_ru.arb` and `app_kk.arb`, following the copy rules in `docs/numer2/DESIGN.md` section 8. Run `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- Import a feature only through its barrel (`lib/features/<name>/<name>.dart`). Direction is `features -> core -> shared`. `lib/core/upcoming/` imports nothing from `lib/features/` or `lib/app/`.
- Tests use `flutter_test` and hand-written fakes. No mocking package.
- Development mechanisms are refused when `APP_ENV=production`.
- UI: only the tokens and components of `docs/numer2/DESIGN.md`. No new colour, radius, text style, icon package or font. Every icon-only control has a tooltip.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (the `core/` line of `AGENTS.md` gains `upcoming/`).

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The two test files of step 7 exist and pass, including per-user isolation and expiry.
- [ ] `grep -rn "features/\|numer_app/app/" lib/core/upcoming` prints nothing.
- [ ] Screenshots of step 9 are attached, and the report answers each review item of `DESIGN.md` section 11 with yes or no.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- None.

## Deliverable
Branch `numer2/p3-10-upcoming-store`, one commit, message `feat: add the local upcoming store and home section` (subject line only). Do not push.
Report: files changed, test output, screenshots, the section 11 answers, user actions still pending.

## Stop and ask if
- The sign-out or deletion code in Settings no longer has a single place to add the call.
