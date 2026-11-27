# P4-18: Events backend: account events handler

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 4 h
**Repo / working dir:** EventsBot (`/Users/anx/events_bot`) @ `main`   **Depends on:** P2-06, P2-07, P4-09

## Goal
When a NUmer account is deleted, the Events backend removes that person's NUmer-only data
and their link to NUmer, while events they created stay published under a "removed user".
Without this the Events flag cannot open beyond testers (PLAN phase 4 gates). Split from
P4-09 (D-42).

## Read first
- `AGENTS.md` of this repo, NUmer `docs/numer2/DECISIONS.md` D-08, D-17, D-42
- NUmer `backend/numer_identity/README.md` "Account events" and the account-events
  contract in NUmer `docs/INFRASTRUCTURE.md` (`/Users/anx/numer_app/...`)
- `backend/app/models/` (every `ForeignKey("users.id"`), `backend/app/models/identity.py`,
  `backend/app/web/firebase_bridge.py`, `backend/app/web/main.py:90-106`,
  `backend/app/config.py:11-70`
- `backend/alembic/versions/20261127_0001_add_user_identities.py` (the current head and its
  style), `scripts/check-migrations.sh`, `scripts/migration-exceptions.txt`
- `backend/pyproject.toml:13,35`, `.env.example:27-29`, `docker/docker-compose.prod.yml:60-64,124-128`,
  `deploy/setup-server.sh:40-50`
- `tests/integration/conftest.py`, `tests/integration/test_firebase_bridge_db.py`

## Context
- Line numbers are from EventsBot `main` at `a5a44ef` plus P4-09. Find code by name if it moved.
- Request: `POST <url>`, body `{"id", "type", "issuer", "subject", "occurredAt"}`, header
  `X-Numer-Signature: t=<unix seconds>,v1=<hex>`; 2xx is success, anything else is retried
  for 72 hours. `numer_identity.verify_account_event(secret=, signature_header=, raw_body=,
  now=)` returns `AccountEvent(id, type, issuer, subject, occurred_at)` or raises
  `SignatureInvalid`. It is in `numer_identity` 0.2.0; `backend/pyproject.toml:35` pins
  `identity-v0.1.0`, which lacks it.
- Every foreign key to `users.id` is `ON DELETE CASCADE` or `SET NULL` except
  `events.creator_user_id`, which is `RESTRICT` (`models/event.py:80-82`). So a user who
  created events cannot be deleted until their events point elsewhere.
- Decisions (D-42):
  - A migration creates one "removed user" row: `telegram_id = -(2**62)` (a value no real
    or provisioned user reaches: Telegram ids are positive, provisioned ones are `-id`),
    `first_name = 'Removed user'`, `role = 'user'`, `is_blocked = true`, `is_verified =
    false`. Its id is looked up by `telegram_id` at run time, never hard-coded.
  - `account.deleted` for issuer `https://securetoken.google.com/<FIREBASE_PROJECT_ID>`:
    find the user through `user_identities (issuer, subject)`.
    - None: nothing to delete.
    - A Telegram user (`telegram_id > 0`, linked through P4-09): delete only the
      `user_identities` rows of that `(issuer, subject)`. The Telegram account and its
      content belong to the bot and stay.
    - A Firebase-provisioned user (`telegram_id < 0` and `password_hash IS NULL`): set
      `creator_user_id` of their events to the removed user, then delete the user row; the
      database cascades and nulls the rest.
    - A native email and password account (`telegram_id < 0`, `password_hash` set) that a
      NUmer identity was attached to: delete only the identity rows, like a Telegram user.
  - `account.disabled` (defined, not yet sent) and any other issuer change nothing.
  - Each handled event id is stored in `processed_account_events`; a replay changes nothing.
  - All of one event is one transaction; any failure answers 500 so NUmer retries.
- CI checks are listed in P4-09 Context; this repo has no `scripts/verify.sh`.

## Steps
1. `backend/pyproject.toml:35`: `tag = "identity-v0.2.0"`; `uv lock` in `backend/`.
2. Settings: `account_events_secret: SecretStr | None = Field(default=None,
   alias="ACCOUNT_EVENTS_SECRET")`. Add `ACCOUNT_EVENTS_SECRET=` to `.env.example` under the
   Firebase lines, `ACCOUNT_EVENTS_SECRET: ${ACCOUNT_EVENTS_SECRET:-}` to both service blocks
   of `docker/docker-compose.prod.yml`, and to `deploy/setup-server.sh` the same required
   check as `FIREBASE_PROJECT_ID` when `FIREBASE_AUTH_ENABLED=true`.
3. Model `backend/app/models/account_event.py`: `ProcessedAccountEvent(Base)`,
   `__tablename__ = "processed_account_events"`, `id: Mapped[str]` (`String(128)`, primary
   key), `processed_at` (`DateTime(timezone=True)`, `server_default=func.now()`). Export it
   from `models/__init__.py`.
4. One Alembic revision `20261128_0001_account_events.py`, `down_revision =
   "20261127_0001"` (or the head at the time; check with `alembic heads`): create the table;
   insert the removed-user row with `op.bulk_insert` on a lightweight `sa.table("users",
   ...)` of the columns it sets; `downgrade` deletes that row (only if no event points at
   it, otherwise raise) and drops the table. Run `scripts/check-migrations.sh`.
5. Service `backend/app/services/account_deletion.py`: `REMOVED_USER_TELEGRAM_ID = -(2**62)`;
   `async def handle_account_event(session, event: AccountEvent, *, expected_issuer: str)
   -> None` implementing the Decisions with SQLAlchemy `select`, `update` and `delete`
   statements (no raw SQL), inside the caller's transaction; it takes the advisory lock
   `firebase:{issuer}:{subject}` (the helper P4-09 moved to `telegram_account_links.py`)
   before reading the identity, and inserts the `ProcessedAccountEvent` last.
6. Router `backend/app/web/routers/account_events.py`: `APIRouter(include_in_schema=False)`,
   `POST /internal/v1/account-events`, status 204. No secret configured -> 503; read the
   raw body and `x-numer-signature`; `SignatureInvalid` -> 401 `Invalid signature`;
   already processed -> 204; else `handle_account_event` and commit. Include it in
   `web/main.py` after `flutter_analytics_router`. Append the file to the single `mypy` command at
   `ci.yml:66`.
7. Docs: `backend/SUPERAPP_BRIDGE.md` "Account deletion" (what goes, what stays, the removed
   user, and that a still-valid ID token used within its last hour provisions a new empty
   user, which is accepted); `docs/INFRASTRUCTURE.md` (endpoint, secret); `docs/PRODUCT.md` (what a user who
   deletes their NUmer account keeps in Telegram).
8. Tests:
   - `tests/integration/test_account_events_db.py` (`-m integration`, Postgres, signing
     with the library's HMAC): a Firebase-provisioned user with two events, a favourite, a
     reminder, a comment, a rating and a friendship -> 204; their events now have the
     removed user as creator and are still listed by the public events endpoint; the user,
     the identity, the favourite, the reminder, the comment, the rating and the friendship
     are gone; analytics rows that named them have `user_id` null. A linked Telegram user
     and a native password account with an attached identity -> only the identity row is
     gone. A replay of the same event -> 204 and no change (add
     a new favourite for another user between calls and assert it stays). An unknown
     subject -> 204. `account.disabled` and another issuer -> 204 and no change. The
     migration upgrades and downgrades on an empty database.
   - `tests/backend/test_account_events_router.py`: no secret -> 503; bad signature and
     stale timestamp -> 401 without touching the session (a fake session that fails the
     test if used); the route is absent from the OpenAPI schema.
9. Run every CI check (P4-09 Context), including the integration job and
   `scripts/check-migrations.sh`.

## Non-goals
- No change to the Telegram link, the bridge's resolution order, the Mini App or the bot
  handlers.
- No deletion of a Telegram account's own data from a NUmer event.
- No handling of `account.disabled` beyond acknowledging it.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- Async sessions passed as arguments; no raw SQL in `app/`; one migration only.
- The body is not trusted before the signature check; body, secret and header are never logged.
- `APP_ENV` and the existing production guards stay authoritative.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings, debug prints, commented-out code or emoji.
- Catch only the specific failure you handle; no bare `except`.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- No secret in code, tests (use a test constant), the repo or CI.
- Do not deploy, do not push, do not connect to any server, database or the production bot.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] Every CI check passes locally, including the integration job on Postgres 16 and `scripts/check-migrations.sh`; the report shows each output.
- [ ] Every case of step 8 has a test that passes.
- [ ] `alembic heads` shows one head.
- [ ] `grep -rn "identity-v0.1.0" backend/pyproject.toml` prints nothing.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Before this task: `USER_ACTIONS.md` D-4 step 3 (push `identity-v0.2.0`).
- Approval: back up the database, set `ACCOUNT_EVENTS_SECRET` in the Events env (the value from D-4), redeploy (the migration runs), then add `{"module": "events", "url": "https://<events host>/internal/v1/account-events"}` to `ACCOUNT_EVENT_TARGETS` and deploy functions (F-3).

## Deliverable
Branch `numer2/p4-18-events-account-events`, one commit, message `feat: handle numer account deletion` (subject line only). Do not push.
Report: files changed, each check's output, user actions still pending.

## Stop and ask if
- `uv lock` cannot fetch `identity-v0.2.0`.
- A foreign key to `users.id` other than `events.creator_user_id` is `RESTRICT` or has no `ondelete`.
- `telegram_id = -(2**62)` is already used by a row in a database you can inspect locally, or the column is not `BigInteger`.
