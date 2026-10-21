# numer-identity

Verifies the bearer token every NUmer campus module backend accepts: a Firebase ID token
issued to a NUmer user. One library, so the module backends cannot drift apart on a
security check (`docs/numer2/DECISIONS.md` D-05, D-07).

It never calls Firebase and needs no service account. It only fetches Google's public
signing certificates and checks the token itself.

## What it checks

`FirebaseVerifier.verify(token)` raises `TokenInvalid` with a `code`, in this order:

| Check | Code |
|---|---|
| token is a string, at most 4096 bytes, three segments | `malformed`, `too-large` |
| header parses, `alg` is `RS256`, `kid` is non-empty | `malformed`, `algorithm` |
| the key source knows the `kid` | `unknown-key` |
| the RS256 signature verifies | `signature` |
| `iss` is `https://securetoken.google.com/<project_id>`, `aud` is `<project_id>` | `issuer`, `audience` |
| `exp` not past, `iat` and `auth_time` not in the future (30 s leeway) | `expired`, `not-yet-valid`, `auth-time` |
| `sub` is 1 to 128 characters | `subject` |
| no `firebase.tenant`; `firebase.sign_in_provider` present, not `anonymous` or `custom` | `tenant`, `provider` |
| `email_verified` is the boolean `true` (unless `require_verified_email=False`) | `email-not-verified` |

On success it returns `FirebaseClaims`, with `roles` parsed from the `numer_roles` claim
(a list of strings; anything else gives no roles). Its `repr` hides `email`, `name` and
`raw`. An optional `revocation_check` coroutine runs last; its exception propagates.

`GoogleX509KeySource` caches the certificates for the response `max-age` (clamped to 5
minutes to 24 hours, 1 hour when absent), refetches at most once per 60 seconds for an
unknown `kid`, and when a refresh fails serves the last keys for up to 24 hours past their
lifetime, retrying no sooner than 30 seconds later. With no usable key it raises
`KeysUnavailable`, never an accept.

## Install

```toml
[project]
dependencies = ["numer-identity"]

[tool.uv.sources]
numer-identity = { git = "https://github.com/anxchywl/NUmer", subdirectory = "backend/numer_identity", tag = "identity-v0.1.0" }
```

The Docker builder stage that runs `uv sync --frozen` needs `git`.

## FastAPI usage

```python
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    keys = GoogleX509KeySource()
    app.state.verifier = FirebaseVerifier(
        project_id=settings.firebase_project_id, key_source=keys
    )
    yield
    await keys.aclose()


app = FastAPI(lifespan=lifespan)


async def current_user(request: Request) -> FirebaseClaims:
    try:
        token = bearer_token(request.headers.get("authorization"))
        return await request.app.state.verifier.verify(token)
    except TokenInvalid as error:
        raise HTTPException(401, error.code, {"WWW-Authenticate": "Bearer"}) from error
    except KeysUnavailable as error:
        raise HTTPException(503, "identity keys unavailable") from error
```

The project id is configuration the backend reads and passes in; the library reads no
environment variables. Never log the token or the email address.

## Test helpers

`numer_identity.testing` lets a backend test its auth without a network:

- `make_test_keypair()` returns a 2048-bit RSA key pair;
- `valid_claims(project_id, uid, now, **overrides)` returns a valid payload; an override
  replaces a top-level claim, an override of `None` removes it;
- `sign_token(claims, private_key, kid="test", headers=None)` signs with RS256;
- `unsigned_token(claims, kid=...)` and `hs256_token(claims, secret, kid=...)` forge the
  `alg: none` and HS256 tokens a verifier must reject;
- `StaticKeySource({kid: public_key})` replaces the Google key source.

## Development

```bash
./scripts/verify.sh
```

It runs ruff, mypy strict and pytest with a 95% coverage floor. CI runs it in
`.github/workflows/identity.yml`.

## Release

A release is a git tag `identity-v<version>` whose version equals `version` in
`pyproject.toml`. Bump the version, merge, then tag that commit. Never move a tag.
