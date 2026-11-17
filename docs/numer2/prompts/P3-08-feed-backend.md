# P3-08: Feed backend: announcements and the composed feed

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`, folder `functions/`   **Depends on:** P2-02, P0-06

## Goal
Publish editor announcements and compose them with upcoming campus events into one document,
`feed/current`, rebuilt every 30 minutes and whenever an announcement changes (D-21). The
app then reads one document per refresh (P3-09).

## Read first
- `AGENTS.md`, `docs/INFRASTRUCTURE.md` (functions layout, emulator commands)
- `docs/numer2/DECISIONS.md` D-07, D-21, D-37
- `functions/src/index.ts`, `functions/src/roles/roles.ts` (`hasRole`),
  `functions/src/roles/set_user_roles.ts` (the double role check), `functions/src/shared/`
  (`admin.ts`, `app_check.ts`, `validation.ts`)
- `functions/src/aggregates/triggers.ts` (a Firestore trigger),
  `functions/test/emulator/set_user_roles.test.ts` (wrapping a callable),
  `functions/test/rules/stage1.test.ts:1-80, 140-160, 350-365` (rules harness; `feed` cases)
- `functions/scripts/set_roles.js` (owner script pattern), `functions/.env.example`
- `firestore/firestore.rules:345-348, 387-390` (`feed` and `announcements` blocks)
- `functions/package.json`, `functions/jest.config.js`, `functions/jest.emulator.config.js`

## Context
- Functions use the v1 API (`firebase-functions/v1`), Node 22, TypeScript `strict`.
- Rules already exist (P0-06): `feed/{docId}` is `get` for signed-in users, no `list`, no
  write; `announcements/{docId}` denies all client access. This task adds rules tests, not
  rules.
- Roles live in the custom claim `numer_roles`; `hasRole(token, 'numer:editor')` reads it.
  Because a token issued before a demotion still carries the role, `setUserRoles` also
  checks the user's current claims with `auth.getUser`; the publish callables do the same.
- The Events source (D-37): the Events backend's public list `GET <base>/api/events`, which
  answers without authentication. Query `sort=time_asc&relevance=active&limit=30`. Each item
  has `token` (string), `title`, `date` (`YYYY-MM-DD`), `time` (`HH:MM`), `location`,
  `organizer`, `category`, `is_ended` (bool) and more; there is no publish time. Dates and
  times are campus local time, Asia/Almaty, UTC+05:00 with no daylight saving.
- The URL is the function parameter `FEED_EVENTS_URL` (a full URL up to and including
  `/api/events`), read from `process.env`. Absent or empty means announcements only. The
  value is set by the owner in the deployed environment; it is never written into a file
  in this repository.
- An event's `publishedAt` is the time the composer first saw it: taken from the previous
  `feed/current` item with the same id, otherwise now (D-37). Events are ordered with
  announcements by that time.
- Budget: `feed/current` stays under 100 KB. With at most 30 items, titles of at most 100
  characters and bodies of at most 400 characters per language, the worst case is about
  90 KB of Cyrillic text.
- Scheduled functions create a Cloud Scheduler job on deploy; the plan uses three in total
  (`USER_ACTIONS.md` E-3).

## Steps
1. `functions/src/feed/types.ts`: `type LocalizedText = { en: string; ru?: string; kk?:
   string }`; `type FeedItem = { id: string; kind: 'announcement' | 'event'; title:
   LocalizedText; body?: LocalizedText; startsAt?: Timestamp; place?: string; publishedAt:
   Timestamp; pinned: boolean; link?: string }`; `type EventSourceItem = { token: string;
   title: string; date: string; time: string; location: string; is_ended: boolean }`.
2. `functions/src/feed/announcements.ts`:
   - `parseLocalized(value, name, maxLength)`: an object with a non-empty `en` string and
     optional `ru` and `kk` strings, each trimmed and at most `maxLength` characters, no
     other keys; otherwise `invalid-argument`.
   - `publishAnnouncement = functions.https.onCall(async (data, context) => ...)`:
     `requireAppCheck(context, 'publishAnnouncement')`; unauthenticated without
     `context.auth`; `permission-denied` unless `hasRole(context.auth.token,
     'numer:editor')` and `hasRole((await auth.getUser(uid)).customClaims,
     'numer:editor')`; validate `title` (100), `body` (400, optional), `pinned` (boolean,
     default false), `expiresAt` (optional, epoch milliseconds, in the future, at most 365
     days ahead), `link` (optional, `https://` URL, at most 500 characters); write
     `announcements/{auto id}` `{title, body?, pinned, link?, expiresAt?, publishedAt:
     serverTimestamp(), authorUid, retracted: false}`; return `{id}`.
   - `retractAnnouncement = functions.https.onCall(...)`: same gate; `assertId(data?.id,
     'id')`; `not-found` when the document does not exist; update `{retracted: true,
     retractedAt: serverTimestamp(), retractedBy: uid}`; return `{id}`.
3. `functions/src/feed/compose.ts`:
   - `type ComposeDeps = { db: Firestore; now: () => number; eventsUrl: string | undefined;
     fetchEvents: (url: string) => Promise<EventSourceItem[]> }`.
   - `fetchEventsOverHttp(url)`: global `fetch` with a 10 second `AbortSignal.timeout`,
     `?sort=time_asc&relevance=active&limit=30` appended; a non-2xx status, a body that is
     not an array, or an item missing a string field throws. Map only the fields of
     `EventSourceItem`.
   - `eventStartsAt(date, time)`: `Date.parse(`${date}T${time}:00+05:00`)`; `NaN` drops the
     item.
   - `composeFeed(deps)`: read `feed/current` (may not exist) and the announcements with
     `retracted == false` ordered by `publishedAt` descending, limit 60. Drop announcements
     whose `expiresAt` has passed. Events: when `eventsUrl` is set, call `fetchEvents`; on
     any error keep the previous document's event items and set `eventsOk: false`; when
     unset, no events and `eventsOk: true`. Drop events with `is_ended` or `startsAt` before
     now. Event item: `id: 'event_' + token`, `kind: 'event'`, `title: {en: title}`,
     `startsAt`, `place: location`, `publishedAt` as in the Context, `pinned: false`.
     Ranking: the newest two pinned announcements first, newest first, with `pinned: true`;
     every other item (further pinned announcements included, with `pinned: false`) by
     `publishedAt` descending; cut to 30. Write `feed/current` `{items, composedAt:
     serverTimestamp(), eventsOk}` with `set` (whole document). Return the items.
4. `functions/src/feed/triggers.ts`:
   - `composeFeedScheduled = functions.pubsub.schedule('every 30 minutes').onRun(() =>
     composeFeed(defaultDeps()))`;
   - `onAnnouncementWrite = functions.firestore.document('announcements/{id}').onWrite(() =>
     composeFeed(defaultDeps()))`;
   - `defaultDeps()` reads `process.env.FEED_EVENTS_URL` at call time and uses
     `fetchEventsOverHttp`.
   Export the four functions from `functions/src/index.ts`.
5. `functions/.env.example`: add the line `# url of the events public list, empty means
   announcements only` and `FEED_EVENTS_URL=` (empty).
6. `functions/scripts/publish_announcement.js` (same shape as `set_roles.js`, needs `npm run
   build` and `GOOGLE_APPLICATION_CREDENTIALS`): options `--file <json>` (an object with
   `title`, `body`, `pinned`, `expiresAt`, `link` as the callable takes them), `--retract
   <id>`, `--dry-run`. It validates with the same `parseLocalized` (import from `../lib/feed/
   announcements`), writes or retracts with the Admin SDK and prints the id; the trigger
   composes the feed. Add `"feed:publish": "tsc && node scripts/publish_announcement.js"`
   to `package.json` scripts.
7. Unit tests, `functions/test/unit/feed_compose.test.ts` (pure functions only): `parseLocalized`
   accepts `{en}` and `{en, ru, kk}`, rejects a missing `en`, an extra key, an over-long
   string; `eventStartsAt('2026-12-12', '18:00')` equals `Date.UTC(2026, 11, 12, 13, 0)`.
8. Emulator tests, `functions/test/emulator/feed.test.ts`, calling `composeFeed` with a fake
   `fetchEvents` and a fixed `now`, and the wrapped callables:
   - three pinned and five plain announcements: the first two items are the newest two
     pinned with `pinned: true`; the third pinned appears among the rest with `pinned: false`;
   - 40 announcements give 30 items;
   - an expired and a retracted announcement are absent;
   - events with `is_ended`, or in the past, are dropped; future ones appear with `startsAt`
     and `place`;
   - an event seen in the previous feed keeps its `publishedAt`; a new one gets `now`;
   - `fetchEvents` throws: previous event items are kept (minus ended ones), `eventsOk` is
     false, announcements are refreshed;
   - no `FEED_EVENTS_URL`: announcements only, `eventsOk` true;
   - 30 announcements with maximum-length Cyrillic titles and bodies: the serialised
     document is under 100 KB (`Buffer.byteLength(JSON.stringify(items))`);
   - `publishAnnouncement`: unauthenticated rejected; a token without `numer:editor`
     rejected; a token with it but current claims without it rejected; a valid editor
     creates the document; invalid input rejected with `invalid-argument`;
   - `retractAnnouncement`: same gate; an unknown id gives `not-found`; a valid call sets
     `retracted`.
9. Rules tests, `functions/test/rules/feed.test.ts` (harness of `stage1.test.ts`): a
   signed-in user can `get` `feed/current`; cannot `list` `feed`, cannot write it; cannot
   read or write `announcements/x`, even with `numer_roles: ['numer:editor']` in the token;
   a signed-out user cannot `get` `feed/current`.
10. Run `cd functions && npm run build && npm test`, `npm run test:emulator`, and
    `./scripts/verify.sh`.

## Non-goals
- No client code (P3-09). No change to `firestore.rules` (the blocks exist).
- No marketplace items, no group activity, no personalisation (D-21).
- Do not deploy, and do not call the Events backend from a test.

## Constraints
- Offline-first contract: UI never writes Firestore. Mutate Hive through `lib/core/data/storage.dart` with `dirty = true` and `updatedAt = now`.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file: `FEED_EVENTS_URL` stays empty in `.env.example`, and tests use `https://events.test/api/events`.
- Tests use hand-written fakes. No mocking package. Functions and rules are tested against the emulator.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Size (`AGENTS.md` "Size", D-33): every file you create or edit under `lib/`, `packages/*/lib` or `functions/src` stays under 400 lines, every function under about 60. `scripts/check_file_size.sh` (in `verify.sh`) enforces it. A file listed in `scripts/file_size_baseline.txt` may only shrink: when it shrinks, lower its entry in the same commit; when it is split away, remove its entry. Never add a new path to the baseline.
- Catch only the specific failure you handle. Never catch broadly or swallow an error. The one deliberate catch is the Events fetch in `composeFeed`, which keeps the previous items; it rethrows nothing and records `eventsOk: false`.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible. No new npm dependency.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit (`docs/INFRASTRUCTURE.md`: the two collections, the four functions, `FEED_EVENTS_URL`, the scheduler job).
- Error messages returned to the client name what failed and never include stack traces or server data.

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test` exits 0.
- [ ] `cd functions && npm run test:emulator` exits 0, including `feed.test.ts` and `rules/feed.test.ts`.
- [ ] `./scripts/verify.sh` exits 0.
- [ ] `grep -rn "http" functions/.env.example` prints nothing new; `grep -rn "FEED_EVENTS_URL=" functions/.env.example` shows an empty value.
- [ ] The 100 KB case passes.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Before deploying, check the free Cloud Scheduler allowance (three jobs in the plan) and set
  `FEED_EVENTS_URL` in the deployed functions environment (E-3).
- Give your account `numer:editor` with `npm run roles:set`.
- After deploying, publish a test announcement with `npm run feed:publish -- --file <json>`
  and check `feed/current` in the console.

## Deliverable
Branch `numer2/p3-08-feed-backend`, one commit, message `feat: add announcements and the composed news feed` (subject line only). Do not push.
Report: files changed, unit and emulator test output, the measured size of the 30-item case, user actions still pending.

## Stop and ask if
- The Events public list needs authentication, or its items lack `token`, `date`, `time` or
  `is_ended` (open `~/events_bot/backend/app/web/routers/events.py:90-135` and
  `~/events_bot/backend/app/web/schemas.py:28-44` to check before you start).
- Global `fetch` or `AbortSignal.timeout` is not available to the TypeScript build.
