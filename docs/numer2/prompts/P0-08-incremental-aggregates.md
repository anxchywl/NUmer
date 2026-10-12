# P0-08: Incremental study aggregates

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 6 h
**Repo / working dir:** NUmer (`anxchywl/NUmer`) @ `main`   **Depends on:** P0-04

## Goal
Every write to a study session re-reads all of the user's courses and 35 days of sessions,
about 111 document reads per event and 70% of all Firestore reads. Replace the recompute
with a per-user ledger so an event costs about 3 reads, with a public output that is equal
field for field, behind a switch and a shadow comparison.

## Read first
- `AGENTS.md`
- `docs/numer2/RESEARCH.md` sections 5.2 and 5.3
- `functions/src/aggregates/update_user_aggregates.ts` and `functions/src/aggregates/triggers.ts` (every line)
- `lib/features/groups/data/group_aggregation_service.dart` lines 414-480 (how the client reads the payload)
- `functions/test/emulator/` (test style)

## Context
- `onStudySessionWrite` fires on every create, update and delete of
  `users/{userId}/sessions/{sessionId}` and calls `updateUserAggregates(userId)`, ignoring
  `change.before` and `change.after`.
- `updateUserAggregates` reads `users/{u}/groupMemberships`, `users/{u}`, all of
  `users/{u}/courses` and the sessions with `startUtc` in the last 35 local days; it writes
  `users/{u}.groupIds`, then one batch: `groups/{g}/aggregates/{u}` for each group and
  `users/{u}/aggregates/statistics`.
- Payload: `{userId, name, avatarIndex, avatarColorValue, timezoneOffsetMinutes,
  totals: {today, last7Days, lastMonth}, dailyBreakdown: [{date, seconds}] (35 entries),
  lastStudyDate, updatedAt}`.
- A session counts when it is not `deleted`, has `seconds > 0` and a `startUtc`, and its
  course is not `hiddenFromLeaderboard`. Days are local days from `timezoneOffsetMinutes`.
- `onCourseWrite` recomputes on course create, delete, and a change of
  `hiddenFromLeaderboard`.
- Legacy details that must survive exactly (copy them from the code, do not re-derive
  them): `totals.last7Days` is the time since Monday of the current week and
  `totals.lastMonth` is the current calendar month, not rolling windows; `name` is
  `profileName` or `''`; `avatarIndex` is the user document's `avatarIndex` or `null`;
  `avatarColorValue` has a default; the 35-day list is built the way the legacy loop builds
  it.
- The client must not need any change: the payload keys, types and meaning stay identical.
- The same event can be delivered twice or out of order. `context.timestamp` of a trigger is
  the time the write happened and is the same for a redelivery.
- Triggers are called in the test process with `firebase-functions-test`; the functions
  emulator is not started.

## Steps
1. Refactor without changing behaviour: split the legacy function into
   - `loadLegacyInputs(userId)`: all the reads, returning `{groupIds, user, hiddenCourseIds,
     contributions}` where a contribution is `{sessionId, courseId, day: 'YYYY-MM-DD', seconds}`
     for each counting session in the window (hidden ones included, with their `courseId`);
   - `derivePayload(input: {user, hiddenCourseIds, contributions, now})`: a pure function in
     `functions/src/aggregates/derive.ts` that produces the payload without `updatedAt`, where
     `user` is `{profileName, avatarIndex, avatarColorValue, timezoneOffsetMinutes}` as read
     from the user document. Move the legacy period and day logic into it unchanged;
   - `writeAggregates(userId, groupIds, payload)`: the batch.
   `updateUserAggregates` calls the three in order. Add
   `functions/test/unit/derive.test.ts` covering: totals over the three periods, hidden courses
   excluded, 35 zero-filled days, `lastStudyDate`, a timezone offset that moves a session
   across midnight. Commit nothing yet; this is the base for the next steps.
2. Add `functions/src/aggregates/ledger.ts` with pure functions:
   - `contributionOf(sessionId, data | undefined, tzMinutes, windowStartDay)` returns `null`
     when the document is missing, `deleted`, has `seconds <= 0`, has no `startUtc`, or its day
     is before `windowStartDay`; otherwise `{c: courseId, d: day, s: seconds}`;
   - `applyToLedger(ledger, sessionId, contribution, eventTimeMs)` returns
     `{ledger, changed}`: no change when the stored entry has the same `c`, `d`, `s`, or when
     the stored entry's `t` is newer than `eventTimeMs`; otherwise the entry is set (with
     `t: eventTimeMs`) or removed;
   - `pruneLedger(ledger, windowStartDay)` removes entries older than the window;
   - `payloadHash(payload)`: SHA-256 of a stable JSON serialisation.
   Unit-test every row of this table in `functions/test/unit/ledger.test.ts`:

   | case | expected |
   |---|---|
   | create | entry added |
   | update, seconds changed | entry replaced |
   | update, start moved to another day | entry replaced with the new day |
   | update, course changed | entry replaced |
   | soft delete, or seconds to 0 | entry removed |
   | un-delete | entry added |
   | hard delete | entry removed |
   | notes or `updatedAt` only | `changed` is false |
   | same event twice | second time `changed` is false |
   | older event after a newer one | `changed` is false |
3. Add `functions/src/aggregates/incremental.ts` with
   `applySessionEvent(userId, sessionId, change, eventTimeMs, options)`, where the caller passes
   `eventTimeMs = Date.parse(context.timestamp)`. Order:
   1. With plain reads, get `users/{u}/aggState/v1` and `users/{u}`. If the user document does
      not exist, return. A rebuild is needed when the state document is missing, `v != 1`, its
      `tz` differs from the user's `timezoneOffsetMinutes`, or `rebuiltAt` is more than 7 days
      old. If so, call `loadLegacyInputs` now and build a ledger and a `hidden` list from it;
      every rebuilt entry gets `t` = the time of the rebuild, so an event older than the
      rebuild is ignored.
   2. In one Firestore transaction: read the state document again, `users/{u}` and
      `users/{u}/groupMemberships`. If a rebuild was prepared and the state document still
      needs one, use the rebuilt ledger; if another event has written a valid state meanwhile,
      use that and discard the prepared one.
   3. Compute the contribution from `change.after`, apply it, prune.
   4. Derive the payload with `derivePayload` from the ledger entries and `hidden`.
   5. Compute `payloadHash` over the payload together with the sorted list of group ids (the
      group ids are hashed, not added to the payload), so joining a group causes a write.
   6. If the hash differs from the stored one, write the aggregates for each group and
      `users/{u}/aggregates/statistics` exactly as `writeAggregates` does.
   7. Write the state document `{v: 1, tz, hidden, ledger, rebuiltAt, payloadHash}` when the
      ledger or the hash changed, and always after a rebuild. Otherwise write nothing.
   Do not write `users/{u}.groupIds` on this path.
   Log one line per event: `functions.logger.info('aggregate_event', {uid, reads, wrote})`,
   where `reads` is the number of document snapshots the code received in that event,
   including each membership document.
4. Add `applyCourseEvent(userId, courseId, change)`. The `hidden` list is the set of course ids
   whose document has `hiddenFromLeaderboard === true`: on a create add the id when the flag is
   true; on an update add or remove it according to the new value, only if the value changed;
   on a delete remove it. When the list changes, re-derive and write as above. Otherwise
   return without reading anything. If the state document does not exist, do nothing (the next
   session event rebuilds it).
5. Build the two trigger handlers with a factory in `functions/src/aggregates/handlers.ts`:
   `createAggregateHandlers({mode: 'on' | 'off', shadowPercent: number, derive = derivePayload})`
   returning `{onSession, onCourse}`. `functions/src/aggregates/triggers.ts` calls it once with
   `AGG_INCREMENTAL` (`on` or `off`, default `off`) and `AGG_SHADOW_PERCENT` (0 to 100,
   default 0) from the environment. Tests call the factory directly with the values and the
   `derive` they need.
   - `off`: run the legacy path. A user is shadowed when
     `stableHash(userId) % 100 < shadowPercent` (choose by user, not by event, so a shadowed
     user's private state sees every one of their events). For a shadowed user, apply every
     session and course event to the private state with a variant that never writes the public
     aggregates, compare its payload with the legacy payload (ignoring `updatedAt`), and on a
     difference log
     `functions.logger.error('aggregate_shadow_mismatch', {uid, sessionId, keys})` where `keys`
     are the differing top-level keys.
   - `on`: run only the incremental path. A user who was never shadowed has no state document
     and is rebuilt on their first event.
6. `functions/test/emulator/incremental.test.ts`:
   - Equivalence: seed a user with 2 groups, 5 courses (1 hidden) and 60 sessions over 40 days
     from a fixed seed; then apply 40 random events (create, edit seconds, move day, change
     course, soft delete, un-delete, notes-only edit, toggle hidden). After each event the
     documents written by the incremental path equal those written by the legacy path, apart
     from `updatedAt`.
   - Idempotency: delivering one event twice changes no document the second time.
   - Out of order: an older event delivered after a newer one changes nothing.
   - Notes-only edit: zero writes.
   - After joining a second group, a notes-only event writes the aggregate for the new group.
   - Timezone change on the user document: the next event rebuilds and the result equals the
     legacy result.
   - Read count: after the first event for a user, an event performs at most 5 document reads
     (count through the `reads` value in the log line or a counter you expose for tests).
   - Shadow mode: handlers created with `mode: 'off'`, `shadowPercent: 100` and a deliberately
     wrong `derive` log `aggregate_shadow_mismatch`; with the real `derive`, 40 events log
     none.
7. Document the two switches in `functions/.env.example` and, in two sentences, in `docs/INFRASTRUCTURE.md` under the Cloud Functions table.
8. Run `npm run build`, `npm test`, `npm run test:emulator`, `./scripts/verify.sh`.

## Non-goals
- Do not change the public payload: no key added, removed, renamed or retyped.
- Do not change the client.
- Do not delete the legacy path; it is the rollback.
- Do not add a scheduled function.
- Do not put the ledger or course ids into any public document.
- Do not edit `firestore/firestore.rules` (P0-06 already denies `users/{uid}/aggState`).

## Constraints
- Cloud Functions keep the v1 API style (`firebase-functions/v1`) and the default region already in use. Do not change a deployed function's name, trigger path or region.
- Client-supplied ids, emails and text are validated before use. Errors returned to clients are generic; details go to `functions.logger`.
- Server-only collections are written with the Admin SDK only and are denied to clients in `firestore/firestore.rules`.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.
- `derivePayload` is the single implementation of the payload for both paths.
- The state document stays under 100 KB for 1000 ledger entries (entry keys are one letter).

## Acceptance criteria
- [ ] `cd functions && npm run build && npm test && npm run test:emulator` exits 0.
- [ ] The equivalence test runs at least 40 events and compares after each one.
- [ ] With `AGG_INCREMENTAL` unset, the exports and behaviour are the legacy ones (the existing tests still pass).
- [ ] `./scripts/verify.sh` exits 0.
- [ ] The report states the reads per event on both paths, counted the same way (snapshots received) in the equivalence test.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Deploy with the switch off and shadow at 5 percent; check logs for `aggregate_shadow_mismatch` for 3 days; then turn the switch on (`docs/numer2/USER_ACTIONS.md` B-6).

## Deliverable
Branch `numer2/p0-08-incremental-aggregates`, one commit, message `perf: make study aggregates incremental behind a switch` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- The legacy code computes a total in a way `derivePayload` cannot reproduce from per-session contributions.
- The equivalence test finds a difference you cannot explain as a legacy bug (report it; do not paper over it).
- A session can count toward the window without a `startUtc`.
