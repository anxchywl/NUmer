# P4-12: Muto backend: block user, moderation actions, text filter

**Recommended model:** opus   **Effort:** high
**Risk:** high   **Est.:** 6 h
**Repo / working dir:** Muto (`/Users/anx/muto`) @ `main`   **Depends on:** P2-05, P2-07

## Goal
Give the marketplace the user-content controls App Review guideline 1.2 requires (D-27):
a user can block a seller, an operator can hide a listing and suspend an account with an
audit trail, reports get a status, and a listing with a banned word cannot be published.
The account-events handler is P4-19 (D-42 split).

## Read first
- `AGENTS.md` of this repo, NUmer `docs/numer2/DECISIONS.md` D-27, D-42
  (`/Users/anx/numer_app/docs/numer2/DECISIONS.md`)
- `backend/app/infrastructure/db/models/{user,listing,community}.py`
- `backend/app/application/listing_service.py:48-160` (`serialize_listing`,
  `_apply_filters`, `browse_listings`), `:271-333` (`listing_suggestions`, `get_listing`),
  `:334-460` (`_apply_draft`, `create_listing`, `update_listing`, `change_listing_status`)
- `backend/app/application/community_service.py` (favourites, seller pages, reports),
  `report_operations.py`, `backend/app/api/{listings,sellers,favorites,reports,operations,router,schemas,errors}.py`
- `backend/app/dependencies.py` (`CurrentPrincipal`, `CurrentAdmin`), `backend/app/config.py`,
  `backend/app/domain/{listings,reports,errors}.py`
- `backend/migrations/versions/20260818_0001_whatsapp_contact.py` (head and style),
  `tests/integration/test_community_api.py`, `tests/integration/test_listings_api.py`,
  `tests/conftest.py`, `docs/API.md`, `.github/workflows/ci.yml:104-175`

## Context
- Line numbers are from Muto `main` at `9467cc5`. Find code by name if it moved.
- Listing statuses are `active`, `reserved`, `sold`, `hidden`, `removed`; `hidden` is the
  owner's own state and the expiry state (`get_listing`, `:313-318`), so an operator hide
  must not reuse it, or the owner could undo it. Accounts are `active` or `suspended`; a
  suspended user already gets 403 on every request (`application/identity.py:58-59`) and
  their listings already vanish from browse, suggestions, detail and seller pages
  (`User.account_status == "active"` filters).
- Operators are principals with `is_admin` (`dependencies.py:49-53`, `CurrentAdmin`); the
  only operator endpoint is `GET /api/v1/operations/reports`.
- Reports: `reports(reporter_id, listing_id, reason, note)` with one report per reporter
  and listing; no status.
- Decisions (D-42):
  - Block: table `user_blocks(blocker_id, blocked_id, created_at)`, primary key on the
    pair, both FKs `ON DELETE CASCADE`, a check `blocker_id <> blocked_id`. For the
    blocker, a blocked seller's listings are absent from browse and search, suggestions,
    favourites and seller listings. The seller's profile and a listing detail opened by id
    still open, so the blocker can unblock from them (P4-20); both carry
    `seller_blocked: true` for the blocker.
  - A listing the principal reported is absent from their browse, search, suggestions,
    favourites and seller listings at once; its detail still opens.
  - Operator hide: `listings.moderation_hidden_at timestamptz null`. Set -> absent
    everywhere for everyone except the owner, whose detail and "my listings" show it with
    `moderation_hidden: true`; the owner cannot change its status while it is set
    (409 `listing_moderated`).
  - Reports gain `status` (`open`, `actioned`, `dismissed`, default `open`), `resolved_at`,
    `resolved_by_id` (FK users, `SET NULL`).
  - Audit: `moderation_actions(id uuid, actor_id -> users SET NULL, action, listing_id ->
    listings SET NULL, user_id -> users SET NULL, report_id -> reports SET NULL, reason
    text not null, created_at)`; `action` in `hide_listing`, `restore_listing`,
    `suspend_user`, `unsuspend_user`, `dismiss_report`.
  - Text filter: setting `LISTING_BLOCKED_WORDS`, a comma-separated list, default empty.
    A listing's `title`, `description` and `wanted_items` are casefolded and split into
    words with `re.findall(r"\w+", text)`; any word in the list rejects the create or
    update with 422 `listing_text_blocked` and the message `This text contains words that
    are not allowed.` Matching is whole words only.
- CI runs `pytest tests --cov=app --cov-fail-under=80` against Postgres 16
  (`ci.yml:111-175`); `./scripts/verify.sh` runs only `tests/unit`.

## Steps
0. Make room in `listing_service.py` (595 lines) first: move `serialize_listing` and
   `serialize_listing_rows` (`:48-110`) into `application/listing_serialization.py` and
   `listing_suggestions` (`:271-296`) into `application/listing_suggestions.py`, unchanged,
   re-importing them where they are used. Then edit.
1. Models: `UserBlock` and `ModerationAction` in `models/community.py` (or a new
   `models/moderation.py` if that file would pass 400 lines);
   `Listing.moderation_hidden_at`; `Report.status`, `resolved_at`, `resolved_by_id` with a
   check on `status`.
2. One Alembic revision `20261128_0001_moderation.py` (`down_revision = "20260818_0001"`, or
   the head at the time) creating the two tables, adding the columns (existing reports get
   `open`), and their indexes: `user_blocks(blocked_id)`, `moderation_actions(created_at)`,
   `reports(status, created_at)`. `downgrade` reverses it.
3. Visibility, one helper `def visible_to(principal: Principal) -> list[ColumnElement[bool]]`
   in a new `backend/app/application/visibility.py` returning the extra conditions (no moderation hide; owner not
   blocked by the principal; not reported by the principal), applied in `_apply_filters`,
   `listing_suggestions` (which now takes the principal; update its router call),
   `community_service.favorite_page` and `seller_listings`. `get_listing` and
   `seller_profile` add `seller_blocked` for the principal; `get_listing` answers 404 for a
   moderation-hidden listing unless the principal owns it. `serialize_listing` adds
   `moderation_hidden` for the owner only.
4. Block API `backend/app/api/blocks.py` (`/api/v1/blocks`, `CurrentPrincipal`):
   `PUT /{seller_id}` (204, idempotent; 404 for an unknown or suspended user; 422 for
   yourself), `DELETE /{seller_id}` (204, idempotent), `GET` (the blocked sellers, newest
   first, cursor-paginated like `favorite_page`, each with `seller_id`, `display_name`,
   `blocked_at`). Service in `community_service.py` or a new `block_service.py`.
5. Operator API in `api/operations.py` (`CurrentAdmin`), each with body `{reason: str
   (1..500), report_id: uuid | null}` and one `ModerationAction` row in the same
   transaction: `POST /listings/{id}/hide`, `POST /listings/{id}/restore`, `POST
   /users/{id}/suspend`, `POST /users/{id}/unsuspend`, `POST /reports/{id}/dismiss` (body
   `{reason}`). A hide or suspend with a `report_id` marks that report `actioned`. Every
   one is idempotent on state (hiding a hidden listing changes nothing and writes no
   second action). Hide works on any listing that is not `removed` (404 otherwise); while
   `moderation_hidden_at` is set the owner can neither change the status nor edit the text
   (409 `listing_moderated`), and expiry does not clear it. `GET /reports` gains a `status`
   query (`open` default), and `OperationalReportResponse` (`api/schemas.py:138-145`) and
   its Dart twin gain `status`, `resolved_at`, `seller_id`, `seller_account_status` and
   `listing_moderation_hidden`, which P4-20 needs to choose its actions.
6. `change_listing_status` refuses with 409 `listing_moderated` while
   `moderation_hidden_at` is set.
7. Text filter: `listing_blocked_words` in `config.py` (alias `LISTING_BLOCKED_WORDS`,
   parsed into a `frozenset` of casefolded words), the check in `domain/listings.py` as
   `def contains_blocked_word(texts: Iterable[str | None], words: frozenset[str]) ->
   bool`, called from `create_listing` and `update_listing` before any write. Add
   `LISTING_BLOCKED_WORDS=` to `.env.example` and the production env example with a comment
   that the owner fills it.
8. Docs: `docs/API.md` (the new endpoints, fields and errors), `docs/PRODUCT.md` (block,
   report status, moderation, the filter), `docs/ARCHITECTURE.md` "Security boundaries" (`:255`).
9. Tests:
   - `tests/unit/test_listing_domain.py` (extend): whole-word matching (`"ass"` does not
     match `"class"`), casefolding, `None` fields, an empty list blocks nothing.
   - `tests/integration/test_blocks_api.py`: block, list, unblock, idempotency, self and
     unknown; after a block the seller's listings are absent from browse, search with a
     matching query, suggestions, favourites and the seller listing page; their profile and
     listing detail still open with `seller_blocked: true` for the blocker and `false` for
     another user. The operator report list returns the five new fields.
   - `tests/integration/test_moderation_api.py`: each operator endpoint for an admin and
     403 for a non-admin; hide removes the listing from browse, search and suggestions for
     a stranger and keeps it in the owner's detail with `moderation_hidden: true`; the
     owner's status change answers 409; restore brings it back; suspend hides all the
     user's listings everywhere and their next request answers 403; unsuspend restores
     both; a report linked to a hide becomes `actioned`, a dismissed one `dismissed`; each
     action writes exactly one audit row, a repeated action none.
   - `tests/integration/test_reports_visibility.py`: after reporting, the listing is
     absent from the reporter's browse and suggestions and still opens by id.
   - `tests/integration/test_listings_api.py` (extend): create and update with a blocked
     word answer 422 `listing_text_blocked` and write nothing.
   - `tests/integration/test_migrations.py` (extend): upgrade and downgrade the new
     revision.
10. Run `./scripts/verify.sh` and the CI command `uv run --frozen pytest tests --cov=app
    --cov-fail-under=80 -q` against a local Postgres 16.

## Non-goals
- No account-events handler (P4-19). No Flutter change (P4-13, P4-20).
- No automatic action on a report count; no appeal flow; no image moderation.

## Constraints
- Follow this repo's `AGENTS.md`; NUmer `DECISIONS.md` section F applies where it has no rule.
- Role comes from the resolved credential and is checked at every operator endpoint; the client never asserts it.
- One migration; no raw SQL outside it; every state change and its audit row in one transaction.
- Size (D-42): a file you create stays under 400 lines. New logic meant for a file already over 400 lines goes into a new file; the mechanical migration (renames, `.of(context)`, focus-mode wiring) may lengthen such a file, and the report lists every edited file over 400 lines with its line count before and after.
- Comments only for a non-obvious why: lowercase, one line, no trailing punctuation. No docstrings, debug prints, commented-out code or emoji.
- Catch only the specific failure you handle.
- No secret or word list in the repository; the list comes from the environment.
- Do not deploy, do not push, do not connect to any server.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0, and the CI pytest command passes on Postgres 16 with the floor of 80.
- [ ] Every case of step 9 has a test that passes.
- [ ] `alembic heads` shows one head.
- [ ] `wc -l backend/app/application/listing_service.py` is below 595.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).

## User actions
- Approval: back up the database, set `LISTING_BLOCKED_WORDS` in Muto's production env, redeploy (the migration runs) (`USER_ACTIONS.md` F-3).
- Give your own account the `muto:admin` role if it lacks it (`USER_ACTIONS.md` D-2 procedure).

## Deliverable
Branch `numer2/p4-12-muto-moderation`, one commit, message `feat: add blocking, moderation actions and a text filter` (subject line only). Do not push.
Report: files changed, both test commands' output, user actions still pending.

## Stop and ask if
- Postgres 16 is not available for the integration tests.
- An existing endpoint returns listings through a query that the helper of step 3 cannot reach.
- `is_admin` is not set from the token's role claim for Firebase principals.
