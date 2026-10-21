import base64
import hashlib
import hmac
import json
from collections.abc import Mapping
from typing import Any

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey, RSAPublicKey

from numer_identity.keys import StaticKeySource

__all__ = [
    "StaticKeySource",
    "hs256_token",
    "make_test_keypair",
    "sign_token",
    "unsigned_token",
    "valid_claims",
]


def make_test_keypair() -> tuple[RSAPrivateKey, RSAPublicKey]:
    private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private_key, private_key.public_key()


def sign_token(
    claims: Mapping[str, Any],
    key: RSAPrivateKey,
    *,
    kid: str = "test",
    headers: Mapping[str, Any] | None = None,
) -> str:
    return jwt.encode(
        dict(claims),
        key,
        algorithm="RS256",
        headers={"kid": kid, **(headers or {})},
    )


def _segment(value: Mapping[str, Any]) -> str:
    raw = json.dumps(value, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def unsigned_token(claims: Mapping[str, Any], *, kid: str = "test") -> str:
    header = _segment({"alg": "none", "typ": "JWT", "kid": kid})
    return f"{header}.{_segment(claims)}."


def hs256_token(claims: Mapping[str, Any], secret: bytes, *, kid: str = "test") -> str:
    header = _segment({"alg": "HS256", "typ": "JWT", "kid": kid})
    signing_input = f"{header}.{_segment(claims)}"
    digest = hmac.new(secret, signing_input.encode(), hashlib.sha256).digest()
    signature = base64.urlsafe_b64encode(digest).rstrip(b"=").decode()
    return f"{signing_input}.{signature}"


def valid_claims(
    project_id: str, uid: str, now: float, **overrides: Any
) -> dict[str, Any]:
    issued = int(now)
    claims: dict[str, Any] = {
        "iss": f"https://securetoken.google.com/{project_id}",
        "aud": project_id,
        "sub": uid,
        "iat": issued,
        "auth_time": issued,
        "exp": issued + 3600,
        "email": "student@nu.edu.kz",
        "email_verified": True,
        "name": "Test User",
        "firebase": {"identities": {}, "sign_in_provider": "password"},
    }
    for name, value in overrides.items():
        if value is None:
            claims.pop(name, None)
        else:
            claims[name] = value
    return claims
