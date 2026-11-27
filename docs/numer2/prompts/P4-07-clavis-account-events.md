# P4-07: Clavis backend: account events handler

**Recommended model:** sonnet   **Effort:** medium
**Risk:** med   **Est.:** 3 h
**Repo / working dir:** Clavis (`/Users/anx/Clavis`) @ `main`   **Depends on:** P2-07, P2-04

## Goal
When a NUmer account is deleted, Clavis releases that person's future bookings, keeps the
past schedule without their identity, and forgets their requests and limits. Without this
the piano room flag cannot open beyond testers (PLAN phase 4 gates).

## Read first
- `AGENTS.md` of this repo, NUmer `docs/numer2/DECISIONS.md` D-08, D-42
- NUmer `backend/numer_identity/README.md` "Account events" and
  `docs/INFRASTRUCTURE.md` (the account-events contract: request, header, retries)
  (`/Users/anx/numer_app/...`)
- `backend/app/infrastructure/store/sqlite.py` (205 lines), `backend/app/application/ports.py`,
  `backend/app/config.py:31-253`, `backend/app/main.py:35-149`, `backend/app/api/router.py`,
  `backend/app/api/operator.py` (router pattern), `backend/app/infrastructure/services.py`
- `backend/pyproject.toml:12,29`, `deploy/production.env.example`, `deploy/preflight.sh`,
  `docs/API.md`, `backend/tests/unit/test_sqlite_store.py`, `test_bookings_api.py`

## Context
- Line numbers are from Clavis `main` at `b4e08d6`. Find code by name if it moved.
- NUmer sends `POST <url>` with body `{"id", "type", "issuer", "subject", "occurredAt"}` and
  header `X-Numer-Signature: t=<unix seconds>,v1=<hex>`; any 2xx is success, anything else
  is retried for 72 hours. `numer_identity.verify_account_event(secret=...,
  signature_header=..., raw_body=..., now=...)` returns an `AccountEvent(id, type, issuer,
  subject, occurred_at)` or raises `SignatureInvalid`.
- `verify_account_event` is in `numer_identity` 0.2.0. `backend/pyproject.toml:29` pins
  `tag = "identity-v0.1.0"`, which does not contain it. The owner pushes `identity-v0.2.0`
  (`USER_ACTIONS.md` D-4 step 3) before this task.
- Bookings are keyed by `subject` = the Firebase uid (`resolvers.py:150-156`); the issuer of
  NUmer's tokens is `https://securetoken.google.com/<FIREBASE_PROJECT_ID>`.
- Tables (`sqlite.py:17-42`): `bookings(id, subject, slot_start, status, created_at,
  updated_at)`, `booking_requests(subject, idempotency_key, slot_start, booking_id -> bookings,
  created_at)`, `weekly_limits(subject, weekly_limit, updated_at)`. `SCHEMA_VERSION = 1`;
  `_migrate` runs the `CREATE ... IF NOT EXISTS` script and sets `user_version`.
- Decisions (D-42): on `account.deleted` for this project's issuer: every `confirmed`
  booking whose `slot_start` is at or after the clock's now becomes `released`; every other
  booking of the subject gets `subject = 'deleted-account'`; the subject's
  `booking_requests` and `weekly_limits` rows are deleted; all in one write transaction.
  `account.disabled` (defined, not yet sent) and an event for another issuer change nothing.
  Every handled event id is stored in a new table so a retry changes nothing.
- The endpoint is internal: `include_in_schema=False`, not listed in `docs/API.md`'s public
  sections; `docs/INFRASTRUCTURE.md` of this repo names it for the operator.

## Steps
1. `backend/pyproject.toml:29`: `tag = "identity-v0.2.0"`; run `uv lock` in `backend/`.
2. `config.py`: `account_events_secret: SecretStr | None = Field(default=None,
   alias="ACCOUNT_EVENTS_SECRET")`. In `guard_development_features` (the validator at
   `:171`), when `auth_adapter == firebase` and the environment is production, raise
   `ValueError("ACCOUNT_EVENTS_SECRET is required for firebase authentication in
   production")` if it is unset or empty. Add it to `deploy/production.env.example` and to
   the required list in `deploy/preflight.sh` next to `FIREBASE_PROJECT_ID`.
3. Store, `sqlite.py`: `SCHEMA_VERSION = 2`; append to `SCHEMA`
   `CREATE TABLE IF NOT EXISTS processed_account_events (id TEXT PRIMARY KEY, processed_at
   TEXT NOT NULL);`. Add to `SqliteTransaction`: `def was_processed(self, event_id: str) ->
   bool`, `def mark_processed(self, event_id: str) -> None`, and `def forget_subject(self,
   subject: str, now: datetime) -> None` doing the Decisions statements in the order:
   release future confirmed bookings, delete `booking_requests` of the subject, replace the
   subject on the remaining bookings with `'deleted-account'`, delete `weekly_limits` of the
   subject. None of them commits; the `store.write()` context does. Add the three to the
   `BookingTransaction` protocol in `ports.py`.
4. Service: `BookingService.forget_account(self, *, event_id: str, subject: str) -> None`
   (async, like `release`): in one `store.write()` transaction, return if `was_processed`;
   otherwise `forget_subject(subject, self.now())` and `mark_processed(event_id)`. Also
   `BookingService.acknowledge_event(event_id)` that only marks it processed.
5. Router `backend/app/api/account_events.py`: `router = APIRouter(include_in_schema=False)`,
   `@router.post("/internal/v1/account-events", status_code=204)`. Read `await
   request.body()` and the `x-numer-signature` header; with no secret configured answer 503
   with the existing error shape (`ServiceUnavailableError`); read settings from
   `request.app.state.settings`; call `verify_account_event`
   with `now=time.time()`; `SignatureInvalid` -> 401 (`UnauthorizedError` with code
   `signature_invalid`). Then: type `account.deleted` and issuer equal to
   `f"https://securetoken.google.com/{settings.firebase_project_id}"` -> `forget_account`;
   any other valid event -> `acknowledge_event`. Include the router in `api/router.py`.
   The request-body size limit middleware already applies.
6. Docs: this repo's `docs/INFRASTRUCTURE.md` names the endpoint, the secret and what is
   kept; `docs/ARCHITECTURE.md` "Backend" section gains one paragraph on the signature check;
   `docs/PRODUCT.md` says what happens to a deleted account's bookings.
7. Tests (`pytest`, hand-written fakes):
   - `tests/unit/test_sqlite_store.py` (extend): `forget_subject` releases a future
     confirmed booking (its slot becomes bookable again), anonymises a past `completed`
     booking and a past `confirmed` one, deletes the subject's requests and limit, and
     leaves another subject's rows unchanged; migrating a version-1 file adds the table.
   - `tests/unit/test_account_events_api.py`: sign bodies with the same HMAC as the
     library (`hmac.new(secret, f"{t}.".encode() + body, sha256)`); valid `account.deleted`
     -> 204 and the subject's bookings are handled; the same event again -> 204 and no
     further change (assert on a booking created between the two calls); bad signature ->
     401 and no change; stale timestamp -> 401; `account.disabled` -> 204 and no change;
     another issuer -> 204 and no change; no secret configured -> 503; the route is absent
     from `/openapi.json` when docs are enabled.
   - `tests/unit/test_config.py` (extend): production with the firebase adapter and no
     secret refuses to start.
8. Run `./scripts/verify.sh`.

## Non-goals
- No change to booking rules, the operator API or the token resolver.
- No Flutter change (P4-06) and no NUmer change; adding the target to
  `ACCOUNT_EVENT_TARGETS` is an owner action.
- No handling of `account.disabled` beyond acknowledging it.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- The endpoint never trusts the body before the signature check, never logs the body, the secret or the header.
- One write transaction per event; a failure inside it leaves nothing half-applied and answers 5xx so NUmer retries.
- `APP_ENV` stays authoritative; no development mechanism is enabled in production.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings, debug prints, commented-out code or emoji.
- Catch only the specific failure you handle.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- No secret in code, tests (use a test constant), the repo or CI.
- Do not deploy, do not push, do not connect to any server.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0 with the backend floor of 90.
- [ ] Every case of step 7 has a test that passes.
- [ ] `grep -rn "identity-v0.1.0" backend/pyproject.toml` prints nothing and `backend/uv.lock` resolves `numer-identity` at the `identity-v0.2.0` commit.
- [ ] `grep -rn "account-events" docs/API.md` prints nothing.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Before this task: `USER_ACTIONS.md` D-4 step 3 (push `identity-v0.2.0`).
- After review (approval): put `ACCOUNT_EVENTS_SECRET` in Clavis's production env (the value created in D-4), redeploy, then add `{"module": "clavis", "url": "https://<clavis host>/internal/v1/account-events"}` to `ACCOUNT_EVENT_TARGETS` and deploy functions (`USER_ACTIONS.md` F-3).

## Deliverable
Branch `numer2/p4-07-clavis-account-events`, one commit, message `feat: handle numer account deletion` (subject line only). Do not push.
Report: files changed, verify output, user actions still pending.

## Stop and ask if
- `uv lock` cannot fetch `identity-v0.2.0`.
- `verify_account_event` in the fetched library has a different signature from Context.
- The store has gained a table that holds a subject and is not listed in Context.
