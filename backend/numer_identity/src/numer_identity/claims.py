from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class FirebaseClaims:
    uid: str
    issuer: str
    email: str | None = field(repr=False)
    email_verified: bool
    name: str | None = field(repr=False)
    sign_in_provider: str
    auth_time: int
    issued_at: int
    expires_at: int
    roles: frozenset[str]
    raw: Mapping[str, Any] = field(repr=False)
