# P4-09: Events backend: Telegram link

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 5 h
**Repo / working dir:** EventsBot (`/Users/anx/events_bot`) @ `main`   **Depends on:** P2-06, P2-07

## Goal
Let a NUmer user attach their NUmer sign-in to the Telegram account they already use with
the Events bot (D-22), so the events and requests they made in Telegram show up in NUmer,
without ever merging accounts silently or moving an admin role.

## Read first
- `AGENTS.md` of this repo (binding), NUmer `docs/numer2/DECISIONS.md` D-07, D-22, D-42
  (`/Users/anx/numer_app/docs/numer2/DECISIONS.md`)
- `backend/app/web/firebase_bridge.py` (whole file), `backend/app/web/flutter_auth.py:57-126`,
  `backend/app/web/routers/flutter_auth.py` (126 lines), `backend/app/web/schemas.py:409-414`
- `backend/app/models/identity.py`, `backend/app/models/user.py`, `backend/app/models/friend.py`
- `backend/app/handlers/start.py:1-80`, `backend/app/main.py:95-130`, `backend/app/handlers/__init__.py`
- `backend/app/db/redis.py`, `backend/app/web/telegram.py:1-40` (`get_bot_username`)
- `backend/SUPERAPP_BRIDGE.md`, `tests/integration/conftest.py`,
  `tests/integration/test_firebase_bridge_db.py`, `tests/backend/test_flutter_cover_upload.py:60-100` (`FakeRedis`)
- `.github/workflows/ci.yml` (the checks to run)

## Context
- Line numbers are from EventsBot `main` at `a5a44ef`. Find code by name if it moved.
- O-4: the bot runs in production, so the bot path is real and needs tests like the API.
- A NUmer request resolves through `resolve_firebase_user` (`firebase_bridge.py:150-169`):
  the `user_identities` row for `(issuer, uid)`, else a verified `@nu.edu.kz` email owner,
  else a new user with `telegram_id = -id` (a "Firebase-provisioned" user). The role of a
  NUmer session comes only from the token claim (`effective_role`); `users.role` is never
  read or written for it.
- A Telegram user has `telegram_id > 0` (`services/users.py:10-30`).
- The bot's user-facing text is inline English in the handlers (`start.py:96`, `:139`);
  `app/localization.py` is not used by any handler and has no catalogs. New bot text
  follows the handlers.
- Telegram `start` parameters allow `A-Z a-z 0-9 _ -` up to 64 characters; callback data up
  to 64 bytes.
- "Content" of a user, for the refusal (D-22): any row in `events` with `creator_user_id`,
  `favorites`, `reminders`, `ratings` or `comments` with `user_id`, `friendships` with
  `user_id` or `friend_user_id`, `friend_requests` with `requester_id` or `recipient_id`, or
  `friend_invites` with `owner_id` equal to that user's id. Not content: `privacy_settings`
  (a default row), verification and reset codes, `user_activity_logs`, `audit_logs`,
  `moderation_logs`, `event_analytics`; deleting the provisioned user removes or nulls them
  through their foreign keys, by design. `users.superapp_user_id` is a legacy key that
  linking leaves untouched.
- Redis key: `telegram_link:<code>`, value JSON `{"issuer", "subject", "email"}`, 600
  seconds. `email` is the token's verified email or null.
- CI runs, in `backend/`: `ruff check app ../scripts ../tests/backend --select
  E9,F63,F7,F82`, `ruff format --check`, `mypy` on the files listed in `ci.yml:66`,
  `bandit`, `pytest ../tests/backend --cov=app --cov-fail-under=30`, and the integration job
  (`alembic upgrade head`, `pytest ../tests/integration -m integration` against Postgres
  16), plus `scripts/check-migrations.sh`. This repo has no `scripts/verify.sh`.
- Bot messages (inline English):

  | Use | Text |
  |---|---|
  | confirm | `Link this Telegram account to the NUmer account {email}?` (`{email}` masked; `your NUmer account` when there is none) |
  | buttons | `Link`, `Cancel` |
  | done | `Linked. Your events now show in NUmer.` |
  | already linked | `This Telegram account is already linked to this NUmer account.` |
  | expired | `This link has expired. Open NUmer and try again.` |
  | content conflict | `This NUmer account already has its own events, favourites or comments here, so it was not linked. Your Telegram account is unchanged.` |
  | taken | `This Telegram account is already linked to another NUmer account.` |
  | cancelled | `Not linked.` |

  Masking: the first character of the local part, `***`, `@`, the domain
  (`a***@nu.edu.kz`).

## Steps
1. `backend/app/services/telegram_account_links.py` (new; add it to the `mypy` list in
   `ci.yml:66`):
   - `async def create_link_code(redis, *, issuer: str, subject: str, email: str | None)
     -> str`: `secrets.token_urlsafe(16)`, `SET telegram_link:<code> <json> EX 600 NX`;
     retry once on a collision; return the code.
   - `async def peek_link(redis, code: str) -> LinkPayload | None` (GET) and `async def
     take_link(redis, code: str) -> LinkPayload | None` (GETDEL), where `LinkPayload` is a
     frozen dataclass of the three fields; malformed JSON is `None`.
   - `def mask_email(email: str | None) -> str | None`.
   - `async def has_content(session, user_id: int) -> bool` over the tables in Context,
     each an `EXISTS` select through the SQLAlchemy models.
   - `async def attach_identity(session, *, telegram_user: User, payload: LinkPayload) ->
     LinkOutcome` with `LinkOutcome` a `StrEnum` of `linked`, `already_linked`, `taken`,
     `content_conflict`. Take the advisory lock `firebase:{issuer}:{subject}` (move
     `_advisory_lock` to this module as the public `advisory_lock` and import it in
     `firebase_bridge.py`).
     Then, in order: the identity row for `(issuer, subject)` already points at the
     Telegram user -> `already_linked`; the Telegram user already has an identity with this
     issuer -> `taken`; the identity row points at another user with `telegram_id > 0` ->
     `taken`; it points at a Firebase-provisioned user that `has_content` ->
     `content_conflict`; it points at one without content -> move the row (`user_id =
     telegram user id`) and delete that user; no row -> add one for the Telegram user.
     Never change `role`, `is_verified` or `email` of either user. Return `linked`.
2. Endpoint in `routers/flutter_auth.py`: `POST /api/flutter/auth/telegram-link`,
   dependency `require_flutter_user`, response `TelegramLinkResponse(url: str,
   expires_in: int)` in `schemas.py`. Only a Firebase-bridged request may call it: read the
   claims the bridge resolved (store `claims` on the user object next to `effective_role`
   in `resolve_firebase_user`, unmapped, same as `effective_role`); without them answer 403
   `Firebase session required`. A user with `telegram_id > 0` answers 409 `Telegram
   already linked`. Without a bot username (`get_bot_username()` is None) answer 503. Else
   create the code and return `https://t.me/<bot>?start=link_<code>` and 600.
3. `FlutterSessionResponse` gains `telegram_linked: bool` (`user.telegram_id > 0`);
   `_session_response` sets it.
4. Bot, `backend/app/handlers/telegram_link.py` (new) with its own `router`:
   - `@router.message(CommandStart(deep_link=True, magic=F.args.startswith("link_")),
     F.chat.type == "private")`: `peek_link`; missing -> "expired"; otherwise answer the
     confirm text with an inline keyboard `Link` (`callback_data="tglink:y:<code>"`) and
     `Cancel` (`"tglink:n:<code>"`).
   - `@router.callback_query(F.data.startswith("tglink:"))`: `n` -> delete the code with
     `take_link`, edit the message to "cancelled". `y` -> `take_link`; missing ->
     "expired"; otherwise `upsert_user_from_telegram(session, callback.from_user)`, then
     `attach_identity`, commit, and edit the message to the text of the outcome. Always
     `await callback.answer()`.
   - Handlers stay thin: all logic is in the service.
   Include the router in `main.py` before `start_router` (`main.py:124`), so the generic
   deep-link handler in `start.py:40` never sees `link_` payloads.
5. Docs: `backend/SUPERAPP_BRIDGE.md` gains "Telegram link": the endpoint, the code's life,
   the bot confirmation, the four outcomes, that roles never move, and the accepted risk that
   whoever opens the link within 10 minutes can confirm it; `docs/PRODUCT.md`
   describes linking for a user; `docs/INFRASTRUCTURE.md` names the Redis key.
6. Tests:
   - `tests/backend/test_telegram_account_links.py` with its own `FakeRedis` (the one in
     `test_flutter_cover_upload.py:60` has no `nx` or `getdel`): `set(key, value, ex=None,
     nx=False)` recording `ex`, `get`, `getdel`, `delete`. `redis>=5` has `getdel` and the
     compose Redis is 7: a code round-trips through `peek_link` and
     `take_link` once (a second `take_link` is `None`); expiry is passed as 600; masking of
     `ab@nu.edu.kz`, `a@x.y`, `None`.
   - `tests/integration/test_telegram_link_db.py` (`-m integration`, Postgres; Redis is the
     same `FakeRedis`, because the CI integration job has no Redis service): link
     success for a NUmer user with no Events row yet; link success moving the identity of
     an empty Firebase-provisioned user (that user is gone afterwards); a replayed code
     (second confirm) answers "expired" and changes nothing; an expired code (deleted key)
     answers "expired"; a Telegram account already linked to another NUmer account ->
     `taken`; content conflict for each kind of content in Context (parametrised) leaves
     both users and the identity row unchanged; after linking a Telegram user whose
     `users.role` is `admin` to a NUmer token without `events:admin`,
     `require_flutter_admin` answers 403 and `GET /api/flutter/auth/session` reports
     `role: "user"` and `telegram_linked: true`.
   - `tests/backend/test_flutter_auth_tokens.py` (extend): the endpoint answers 403 for a
     native Flutter token, 409 for a linked user, and a `t.me` URL with `start=link_` for a
     bridged user.
7. Run every check of Context exactly as CI runs it, including the integration job.

## Non-goals
- No account-events handler (P4-18). No change to the Mini App, `frontend/`, or the
  automatic verified-email attach.
- No unlink flow.
- No new migration: `user_identities` already has what linking needs.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- Sessions are passed as arguments; no raw SQL; routes under `backend/app/web/routers/`; input validated with Pydantic.
- A code is single-use (GETDEL on confirm) and is never logged; the endpoint never returns another user's data.
- Linking never copies or changes a role (D-07, D-22).
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings, debug prints, commented-out code or emoji.
- Catch only the specific failure you handle; no bare `except`.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- Do not deploy, do not push, do not connect to any server or the production bot.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] Every CI check of Context passes locally, including the integration job on Postgres 16; the report shows each command's output.
- [ ] Every case of step 6 has a test that passes.
- [ ] `grep -rn "users.role\|\.role =" backend/app/services/telegram_account_links.py` prints nothing.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Approval: redeploy the Events backend and bot after review (`USER_ACTIONS.md` F-3).
- After P4-11: link your own Telegram account from NUmer and confirm your events appear (F-4).

## Deliverable
Branch `numer2/p4-09-events-telegram-link`, one commit, message `feat: link a telegram account to a numer sign-in` (subject line only). Do not push.
Report: files changed, each check's output, user actions still pending.

## Stop and ask if
- Postgres 16 is not available for the integration tests.
- A table not listed in Context references `users.id` with user-made content (check every `ForeignKey("users.id"` in `backend/app/models/`).
- `resolve_firebase_user` has changed so that the claims cannot be kept on the user object.
