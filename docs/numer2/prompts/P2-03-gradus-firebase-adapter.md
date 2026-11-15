# P2-03: Gradus backend: Firebase adapter

**Recommended model:** sonnet   **Effort:** high
**Risk:** med   **Est.:** 5 h
**Repo / working dir:** Gradus (`anxchywl/Gradus`) @ `main`   **Depends on:** P2-01 (tag `identity-v0.1.0` pushed)

## Goal
Gradus's syllabus-parsing backend verifies a host-issued JWT today (adapter `host`), which
no real host issues. Add an adapter
that verifies NUmer's Firebase ID tokens, so the GPA module inside NUmer can call it as the
signed-in user.

## Read first
- `AGENTS.md` (this repo's rules are binding)
- `docs/ARCHITECTURE.md` (identity section), `docs/INFRASTRUCTURE.md`, `docs/API.md`
- `backend/app/config.py`
- `backend/app/infrastructure/auth/resolvers.py`
- `backend/app/domain/auth.py`, `backend/app/dependencies.py`, `backend/app/main.py`
- `backend/app/api/errors.py`
- `backend/tests/unit/test_auth.py`, `backend/tests/unit/test_config.py`, `backend/tests/conftest.py`
- `deploy/preflight.sh`, `deploy/production.env.example`, `docker/docker-compose.production.yml`, `backend/Dockerfile`

## Context
- NUmer signs users in with Firebase. This backend must accept the Firebase ID token as the
  bearer token and verify it with the shared library `numer_identity` (in the NUmer repo,
  consumed by git tag).
- Library surface: `FirebaseVerifier(project_id=..., key_source=GoogleX509KeySource(...))`,
  `await verifier.verify(token) -> FirebaseClaims(uid, issuer, email, email_verified, name,
  roles, ...)`; `TokenInvalid` (answer 401) and `KeysUnavailable` (answer 503);
  `numer_identity.testing` gives `make_test_keypair`, `sign_token`, `valid_claims`,
  `StaticKeySource` so tests need no network.
- Dependency line for `pyproject.toml`:
  `numer-identity = { git = "https://github.com/anxchywl/NUmer", subdirectory = "backend/numer_identity", tag = "identity-v0.1.0" }`
  under `[tool.uv.sources]`, plus `"numer-identity"` in `dependencies`.
- The Docker image is built with `uv sync --frozen` from `python:3.12-slim`, which has no
  `git`. A git dependency needs `git` in the stage that runs `uv sync`.
- Production Firebase project id: `numer-60744`. It is configuration, never a code default.
- Test helpers: `sign_token` signs RS256 only; `unsigned_token` and `hs256_token` build the
  forged tokens for the negative tests.
- The NUmer repository is public, so `uv lock`, CI and the image build can fetch the
  library without a credential. Contacting github.com and the package index for that is
  allowed in this task.
- If Flutter is not installed, run only the backend part of `./scripts/verify.sh` and say so
  in the report.

- Adapter selection: enum `AuthAdapter` (`backend/app/config.py:26-28`, values `host` and
  `development`), setting `AUTH_ADAPTER` (`:44`), factory `create_principal_resolver`
  (`backend/app/infrastructure/auth/resolvers.py:125-130`), wired in the lifespan
  (`backend/app/main.py:36-38`).
- A resolver implements `resolve(token) -> ExternalIdentity(external_issuer,
  external_subject, account_status, display_name, is_operator)`.
- The backend stores nothing about users. The subject is only a rate-limit and idempotency
  key (`backend/app/api/syllabus.py:46-52`).
- `deploy/preflight.sh:22-31` refuses any production adapter other than `host`. The script
  reads its file from `ENV_FILE`, needs `APP_ENV=production` and `GRADUS_API_DOMAIN`, and
  fails on a dirty working tree.
- The existing `host` adapter stays for one release as the rollback.
- `create_principal_resolver(settings)` is synchronous, takes one argument, and several
  tests call it that way. The lifespan overwrites `application.state.principal_resolver` on
  startup, so a test cannot inject a resolver after `create_app`.
- A 503 already has a domain error: `ServiceUnavailableError(code, message)` in
  `backend/app/domain/errors.py`, rendered by the existing handler.
- `backend/Dockerfile` has a single stage.

## Steps
1. Add the dependency as given in Context and regenerate `backend/uv.lock` with `uv lock`.
2. `backend/app/config.py`: add `firebase` to `AuthAdapter`; add settings
   `FIREBASE_PROJECT_ID` (default empty), `FIREBASE_ROLES_CLAIM` (default `numer_roles`),
   `FIREBASE_OPERATOR_ROLE` (default `gradus:operator`). In the existing validator, when the
   adapter is `firebase`, require a non-empty project id. The default adapter stays `host`.
3. `backend/app/infrastructure/auth/resolvers.py`: add `FirebasePrincipalResolver(verifier,
   operator_role)`. `resolve` calls `verifier.verify(token)` and returns
   `ExternalIdentity(external_issuer=claims.issuer, external_subject=claims.uid,
   display_name=claims.name, is_operator=operator_role in claims.roles)` with the active
   account status. Map `TokenInvalid` to the module's unauthorized error, and
   `KeysUnavailable` to
   `ServiceUnavailableError('auth_keys_unavailable', 'Authentication is temporarily unavailable.')`.
   Add `create_firebase_resolver(settings, key_source: KeySource | None = None) ->
   tuple[TokenIdentityResolver, Callable[[], Awaitable[None]]]`: it builds a
   `GoogleX509KeySource` when none is given, a `FirebaseVerifier`, the resolver, and returns
   the resolver with a function that closes the key source. Leave
   `create_principal_resolver(settings)` unchanged for `host` and `development`; for the
   `firebase` adapter it raises `ValueError`.
4. `backend/app/main.py`: give `create_app` an optional parameter `firebase_key_source` (used by tests). In the lifespan, when the adapter is `firebase`, call `create_firebase_resolver`, store the resolver in `application.state.principal_resolver`, and await its close function after `yield`, the way the syllabus service is closed. Startup must not wait for a key fetch.
5. `backend/Dockerfile`: Split the Dockerfile into two stages with the same `WORKDIR`: a `builder` stage (from the same base image) that installs `git` with `--no-install-recommends`, removes the apt lists, and runs the existing `uv sync --frozen` commands so the virtual environment is created there; and a `runtime` stage that copies the virtual environment from the builder (`COPY --from=builder`), then copies the application files, creates the user and keeps the existing `CMD`, exactly as today. The final image must not contain `git`.
6. `deploy/production.env.example` and `docker/docker-compose.production.yml`: add the three `FIREBASE_*` variables and set `AUTH_ADAPTER=firebase` with `FIREBASE_PROJECT_ID=numer-60744` in the example. `deploy/preflight.sh`: in production accept `firebase` (requiring a non-empty project id) or `host` (with today's checks); keep refusing development tokens.
7. Tests (`backend/tests/unit/test_firebase_auth.py`, tokens minted with
   `numer_identity.testing`, a `StaticKeySource`):
   - a valid token resolves to the uid as subject and the Firebase issuer;
   - wrong audience, wrong issuer, expired, `alg` HS256, unknown kid, unverified email: each is
     unauthorized;
   - a key source that raises `KeysUnavailable` gives 503, not 200 and not 401;
   - `numer_roles` containing `gradus:operator` gives `is_operator` true; the same string in a
     different claim, or a non-list claim, gives false;
   - one route-level test through `require_identity` with a bearer header, built with
     `create_app(settings, firebase_key_source=StaticKeySource(...))`.
   `backend/tests/unit/test_config.py`: `firebase` without a project id is rejected; production
   still rejects `development`.
   `backend/tests/boundaries/test_layer_boundaries.py`: add a test that `numer_identity` is not
   imported under `app/domain`, `app/application` or `app/api`.
8. Update `docs/INFRASTRUCTURE.md` (including its environments table), `docs/API.md`, the identity parts of `docs/ARCHITECTURE.md`, and the comment in `deploy/production.env.example` that calls `host` the only production adapter, to describe the `firebase` adapter as the production one and `host` as deprecated. Run `./scripts/verify.sh`.

## Non-goals
- Do not remove the `host` or `development` adapters.
- Do not change the syllabus API, rate limits or the Flutter packages.
- Do not add a user table.
- Do not deploy.

## Constraints
- Follow this repo's own `AGENTS.md`: layering (domain, application, infrastructure, api), settings only in `config.py`, no bare `except`, no docstrings.
- Production must refuse the development adapter and development tokens, as it does today.
- Do not log tokens, emails or personal data.
- Code conventions from `AGENTS.md`. Comments only for a non-obvious *why*: lowercase, no trailing punctuation, one line. No docstrings, no debug prints, no commented-out code, no emoji.
- Catch only the specific failure you handle. Never catch broadly or swallow an error.
- No unrequested features, abstractions, dependencies or error handling. Edit existing files rather than creating new ones where possible.
- No secrets in code, in committed files or in `--dart-define`. Never write a server address into a file.
- Do not deploy, do not push, do not connect to any server or production project.
- If this change makes `AGENTS.md`, `README.md` or `docs/*` wrong, fix them in the same commit.

## Acceptance criteria
- [ ] `./scripts/verify.sh` exits 0 (backend coverage floor 90).
- [ ] `docker build -t gradus-backend:p203 -f backend/Dockerfile .` succeeds and `docker run --rm --entrypoint sh gradus-backend:p203 -c 'command -v git'` exits 1.
- [ ] After the commit (the script needs a clean tree), with two temporary env files outside the repo that both contain `APP_ENV=production`, `GRADUS_API_DOMAIN=x.example` and `AUTH_ADAPTER=firebase`: `ENV_FILE=<file with FIREBASE_PROJECT_ID=numer-60744> sh deploy/preflight.sh` passes, and the same with an empty project id fails naming it. Show both runs in the report.
- [ ] `grep -rln numer_identity backend/app` lists only files under `backend/app/infrastructure/auth/` and `backend/app/main.py`, and the new boundary test passes.
- [ ] No new comment breaks the comment rule; no debug prints or commented-out code (check the diff).
- [ ] Docs touched by this change are updated, or the report states "no docs affected".

## User actions
- Approval needed: redeploy Gradus with `AUTH_ADAPTER=firebase` and `FIREBASE_PROJECT_ID=numer-60744` (`docs/numer2/USER_ACTIONS.md` D-3 in the NUmer repo).

## Deliverable
Branch `numer2/p2-03-gradus-firebase-adapter`, one commit, message `feat: verify firebase id tokens` (subject line only). Do not push.
Report: files changed, the output of each acceptance command, anything you could not verify, and user actions still pending.

## Stop and ask if
- The tag `identity-v0.1.0` does not exist yet.
- `ServiceUnavailableError` does not exist or is not rendered as 503.
- Docker is not available to check the image.
