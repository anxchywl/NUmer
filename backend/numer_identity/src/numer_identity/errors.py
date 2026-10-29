from typing import Literal

TokenErrorCode = Literal[
    "malformed",
    "too-large",
    "algorithm",
    "unknown-key",
    "signature",
    "issuer",
    "audience",
    "expired",
    "not-yet-valid",
    "auth-time",
    "subject",
    "email-not-verified",
    "provider",
    "tenant",
]


class TokenInvalid(Exception):
    def __init__(self, code: TokenErrorCode) -> None:
        super().__init__(code)
        self.code: TokenErrorCode = code


class KeysUnavailable(Exception):
    pass
