import hashlib
import hmac
import json
from dataclasses import dataclass

_TYPES = ("account.deleted", "account.disabled")
_KEYS = ("id", "type", "issuer", "subject", "occurredAt")


@dataclass(frozen=True, slots=True)
class AccountEvent:
    id: str
    type: str
    issuer: str
    subject: str
    occurred_at: str


class SignatureInvalid(Exception):
    pass


def _parse_header(header: str | None) -> tuple[int, list[bytes]]:
    if not header:
        raise SignatureInvalid("missing signature")
    timestamp: int | None = None
    signatures: list[bytes] = []
    for part in header.split(","):
        name, _, value = part.strip().partition("=")
        if name == "t":
            if not (value.isascii() and value.isdigit() and len(value) <= 20):
                raise SignatureInvalid("malformed signature")
            timestamp = int(value)
        elif name == "v1":
            signatures.append(value.encode())
    if timestamp is None or not signatures:
        raise SignatureInvalid("malformed signature")
    return timestamp, signatures


def _parse_event(raw_body: bytes) -> AccountEvent:
    try:
        payload = json.loads(raw_body)
    except ValueError as error:
        raise SignatureInvalid("malformed body") from error
    if not isinstance(payload, dict):
        raise SignatureInvalid("malformed body")
    values = [payload.get(key) for key in _KEYS]
    fields = [value for value in values if isinstance(value, str) and value]
    if len(fields) != len(_KEYS):
        raise SignatureInvalid("malformed body")
    event = AccountEvent(*fields)
    if event.type not in _TYPES:
        raise SignatureInvalid("unknown event type")
    return event


def verify_account_event(
    *,
    secret: str,
    signature_header: str | None,
    raw_body: bytes,
    now: float,
    tolerance_seconds: int = 300,
) -> AccountEvent:
    if not secret:
        raise ValueError("secret must not be empty")
    timestamp, signatures = _parse_header(signature_header)
    if abs(now - timestamp) > tolerance_seconds:
        raise SignatureInvalid("stale signature")
    signed = f"{timestamp}.".encode() + raw_body
    expected = hmac.new(secret.encode(), signed, hashlib.sha256).hexdigest().encode()
    if not any(hmac.compare_digest(expected, given) for given in signatures):
        raise SignatureInvalid("signature mismatch")
    return _parse_event(raw_body)
