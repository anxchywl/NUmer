import hashlib
import hmac
import json
import tomllib
from pathlib import Path

import pytest

from numer_identity import (
    AccountEvent,
    SignatureInvalid,
    __version__,
    verify_account_event,
)

# the same vector is pinned in functions/test/unit/event_signature.test.ts
SECRET = "test-account-event-secret"
NOW = 1767225600
BODY = (
    b'{"id":"deleted_user-1","type":"account.deleted",'
    b'"issuer":"https://securetoken.google.com/demo-numer",'
    b'"subject":"user-1","occurredAt":"2026-01-01T00:00:00.000Z"}'
)
DIGEST = "877c5684343268c547921c79e56c3c4e5c6e1e48a2e73e12c5f61614ab08b5db"
HEADER = f"t={NOW},v1={DIGEST}"


def sign(body: bytes) -> str:
    signed = f"{NOW}.".encode() + body
    return f"t={NOW},v1={hmac.new(SECRET.encode(), signed, hashlib.sha256).hexdigest()}"


def verify(
    header: str | None = HEADER,
    body: bytes = BODY,
    secret: str = SECRET,
    now: float = NOW,
) -> AccountEvent:
    return verify_account_event(
        secret=secret, signature_header=header, raw_body=body, now=now
    )


def test_accepts_the_shared_vector() -> None:
    assert verify() == AccountEvent(
        id="deleted_user-1",
        type="account.deleted",
        issuer="https://securetoken.google.com/demo-numer",
        subject="user-1",
        occurred_at="2026-01-01T00:00:00.000Z",
    )


@pytest.mark.parametrize("offset", [-300, 300])
def test_accepts_a_timestamp_at_the_tolerance(offset: int) -> None:
    assert verify(now=NOW + offset).subject == "user-1"


def test_accepts_any_of_several_signatures() -> None:
    header = f"t={NOW},v1={'0' * 64},v1={DIGEST}"

    assert verify(header=header).id == "deleted_user-1"


def test_accepts_the_disabled_type() -> None:
    body = BODY.replace(b"account.deleted", b"account.disabled")

    assert verify(header=sign(body), body=body).type == "account.disabled"


def test_rejects_a_changed_body() -> None:
    with pytest.raises(SignatureInvalid):
        verify(body=BODY.replace(b"user-1", b"user-2"))


def test_rejects_a_wrong_secret() -> None:
    with pytest.raises(SignatureInvalid):
        verify(secret="another-secret")


@pytest.mark.parametrize("offset", [-301, 301])
def test_rejects_a_timestamp_outside_the_tolerance(offset: int) -> None:
    with pytest.raises(SignatureInvalid):
        verify(now=NOW + offset)


@pytest.mark.parametrize(
    "header",
    [
        None,
        "",
        "nonsense",
        f"v1={DIGEST}",
        f"t={NOW}",
        f"t=soon,v1={DIGEST}",
        f"t={NOW}.5,v1={DIGEST}",
        f"t={'9' * 5000},v1={DIGEST}",
        f"t={NOW},v1=é",
    ],
)
def test_rejects_a_missing_or_malformed_header(header: str | None) -> None:
    with pytest.raises(SignatureInvalid):
        verify(header=header)


@pytest.mark.parametrize(
    "body",
    [
        b"not json",
        b"\xff",
        b"[]",
        BODY.replace(b"account.deleted", b"account.created"),
        BODY.replace(b'"user-1"', b'""'),
        BODY.replace(b'"user-1"', b"7"),
        json.dumps({"id": "deleted_user-1", "type": "account.deleted"}).encode(),
    ],
)
def test_rejects_a_signed_body_that_is_not_an_event(body: bytes) -> None:
    with pytest.raises(SignatureInvalid):
        verify(header=sign(body), body=body)


def test_refuses_an_empty_secret() -> None:
    with pytest.raises(ValueError):
        verify(secret="")


def test_package_version_matches_the_project() -> None:
    project = Path(__file__).parents[1] / "pyproject.toml"

    assert tomllib.loads(project.read_text())["project"]["version"] == __version__
