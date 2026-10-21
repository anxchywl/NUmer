import time
from collections.abc import Awaitable, Callable, Mapping
from types import MappingProxyType
from typing import Any

import jwt
from jwt.types import Options

from numer_identity.claims import FirebaseClaims
from numer_identity.errors import TokenErrorCode, TokenInvalid
from numer_identity.keys import KeySource
from numer_identity.roles import parse_roles

MAX_TOKEN_BYTES = 4096
MAX_SUBJECT_LENGTH = 128
REJECTED_PROVIDERS = frozenset({"anonymous", "custom"})

_SIGNATURE_ONLY: Options = {
    "verify_signature": True,
    "verify_exp": False,
    "verify_nbf": False,
    "verify_iat": False,
    "verify_aud": False,
    "verify_iss": False,
    "verify_sub": False,
    "verify_jti": False,
    "require": [],
}


def _timestamp(payload: Mapping[str, Any], name: str, code: TokenErrorCode) -> int:
    value = payload.get(name)
    if isinstance(value, bool) or not isinstance(value, int | float):
        raise TokenInvalid(code)
    return int(value)


def _optional_str(value: object) -> str | None:
    return value if isinstance(value, str) else None


class FirebaseVerifier:
    def __init__(
        self,
        *,
        project_id: str,
        key_source: KeySource,
        leeway_seconds: int = 30,
        clock: Callable[[], float] = time.time,
        roles_claim: str = "numer_roles",
        require_verified_email: bool = True,
        revocation_check: Callable[[FirebaseClaims], Awaitable[None]] | None = None,
    ) -> None:
        if not project_id:
            raise ValueError("project_id must not be empty")
        self._project_id = project_id
        self._issuer = f"https://securetoken.google.com/{project_id}"
        self._key_source = key_source
        self._leeway = leeway_seconds
        self._clock = clock
        self._roles_claim = roles_claim
        self._require_verified_email = require_verified_email
        self._revocation_check = revocation_check

    async def verify(self, token: str) -> FirebaseClaims:
        kid = self._check_shape(token)
        key = await self._key_source.get(kid)
        if key is None:
            raise TokenInvalid("unknown-key")
        try:
            payload: dict[str, Any] = jwt.decode(
                token, key, algorithms=["RS256"], options=_SIGNATURE_ONLY
            )
        except jwt.InvalidSignatureError as error:
            raise TokenInvalid("signature") from error
        except jwt.InvalidTokenError as error:
            raise TokenInvalid("malformed") from error
        claims = self._check_claims(payload)
        if self._revocation_check is not None:
            await self._revocation_check(claims)
        return claims

    def _check_shape(self, token: object) -> str:
        if not isinstance(token, str):
            raise TokenInvalid("malformed")
        if len(token.encode()) > MAX_TOKEN_BYTES:
            raise TokenInvalid("too-large")
        if len(token.split(".")) != 3:
            raise TokenInvalid("malformed")
        try:
            header = jwt.get_unverified_header(token)
        except jwt.InvalidTokenError as error:
            raise TokenInvalid("malformed") from error
        if header.get("alg") != "RS256":
            raise TokenInvalid("algorithm")
        kid = header.get("kid")
        if not isinstance(kid, str) or not kid:
            raise TokenInvalid("malformed")
        return kid

    def _check_claims(self, payload: Mapping[str, Any]) -> FirebaseClaims:
        if payload.get("iss") != self._issuer:
            raise TokenInvalid("issuer")
        if payload.get("aud") != self._project_id:
            raise TokenInvalid("audience")
        now = self._clock()
        expires_at = _timestamp(payload, "exp", "expired")
        if now > expires_at + self._leeway:
            raise TokenInvalid("expired")
        issued_at = _timestamp(payload, "iat", "not-yet-valid")
        if issued_at > now + self._leeway:
            raise TokenInvalid("not-yet-valid")
        auth_time = _timestamp(payload, "auth_time", "auth-time")
        if auth_time > now + self._leeway:
            raise TokenInvalid("auth-time")
        uid = payload.get("sub")
        if not isinstance(uid, str) or not 0 < len(uid) <= MAX_SUBJECT_LENGTH:
            raise TokenInvalid("subject")
        firebase = payload.get("firebase")
        if not isinstance(firebase, dict):
            firebase = {}
        if "tenant" in firebase:
            raise TokenInvalid("tenant")
        provider = firebase.get("sign_in_provider")
        if not isinstance(provider, str) or not provider:
            raise TokenInvalid("provider")
        if provider in REJECTED_PROVIDERS:
            raise TokenInvalid("provider")
        email_verified = payload.get("email_verified") is True
        if self._require_verified_email and not email_verified:
            raise TokenInvalid("email-not-verified")
        return FirebaseClaims(
            uid=uid,
            issuer=self._issuer,
            email=_optional_str(payload.get("email")),
            email_verified=email_verified,
            name=_optional_str(payload.get("name")),
            sign_in_provider=provider,
            auth_time=auth_time,
            issued_at=issued_at,
            expires_at=expires_at,
            roles=parse_roles(payload.get(self._roles_claim)),
            raw=MappingProxyType(dict(payload)),
        )
