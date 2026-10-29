import json
import logging

import pytest
from conftest import Clock, KeyEndpoint, certificate_pem
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey, RSAPublicKey

from numer_identity import GoogleX509KeySource, KeysUnavailable, StaticKeySource
from numer_identity.keys import parse_max_age

KeyPair = tuple[RSAPrivateKey, RSAPublicKey]


@pytest.mark.parametrize(
    ("header", "lifetime"),
    [
        (None, 3600.0),
        ("public", 3600.0),
        ("public, max-age=19800, must-revalidate", 19800.0),
        ("MAX-AGE=600", 600.0),
        ("max-age=10", 300.0),
        ("max-age=999999", 86400.0),
        ("max-age=abc", 3600.0),
        ("s-max-age=600", 3600.0),
    ],
)
def test_parse_max_age(header: str | None, lifetime: float) -> None:
    assert parse_max_age(header) == lifetime


async def test_lifetime_follows_max_age(clock: Clock, endpoint: KeyEndpoint) -> None:
    endpoint.cache_control = "max-age=600"
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    assert await source.get("test") is not None
    clock.now += 599
    await source.get("test")
    assert endpoint.requests == 1
    clock.now += 1
    await source.get("test")
    assert endpoint.requests == 2


async def test_missing_cache_control_uses_default(
    clock: Clock, endpoint: KeyEndpoint
) -> None:
    endpoint.cache_control = None
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    await source.get("test")
    clock.now += 3599
    await source.get("test")
    assert endpoint.requests == 1


async def test_stale_keys_served_then_refused(
    clock: Clock, endpoint: KeyEndpoint, caplog: pytest.LogCaptureFixture
) -> None:
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    await source.get("test")
    endpoint.status = 503
    clock.now += 3600
    with caplog.at_level(logging.WARNING, logger="numer_identity.keys"):
        assert await source.get("test") is not None
    assert "HTTPStatusError" in caplog.text
    clock.now += 86400
    assert await source.get("test") is not None
    clock.now += 1
    with pytest.raises(KeysUnavailable):
        await source.get("test")


async def test_failed_refresh_backs_off(clock: Clock, endpoint: KeyEndpoint) -> None:
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    await source.get("test")
    endpoint.status = 500
    clock.now += 3600
    for _ in range(10):
        await source.get("test")
    assert endpoint.requests == 2
    clock.now += 29
    await source.get("test")
    assert endpoint.requests == 2
    clock.now += 1
    endpoint.status = 200
    await source.get("test")
    assert endpoint.requests == 3
    clock.now += 3599
    await source.get("test")
    assert endpoint.requests == 3


async def test_failed_refresh_suppresses_forced_refresh(
    clock: Clock, endpoint: KeyEndpoint
) -> None:
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    await source.get("test")
    endpoint.status = 500
    clock.now += 3600
    assert await source.get("other") is None
    assert await source.get("other") is None
    assert endpoint.requests == 2


async def test_cold_cache_failure_backs_off(
    clock: Clock, endpoint: KeyEndpoint
) -> None:
    endpoint.status = 500
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    for _ in range(3):
        with pytest.raises(KeysUnavailable):
            await source.get("test")
    assert endpoint.requests == 1


@pytest.mark.parametrize(
    "raw",
    [
        b"not json",
        json.dumps(["a"]).encode(),
        json.dumps({"test": 1}).encode(),
        json.dumps({"test": "not a pem"}).encode(),
    ],
)
async def test_bad_key_document(
    raw: bytes, clock: Clock, endpoint: KeyEndpoint
) -> None:
    endpoint.raw = raw
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    with pytest.raises(KeysUnavailable):
        await source.get("test")


async def test_non_rsa_certificate(clock: Clock, endpoint: KeyEndpoint) -> None:
    endpoint.body = {"test": certificate_pem(ec.generate_private_key(ec.SECP256R1()))}
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    with pytest.raises(KeysUnavailable):
        await source.get("test")


async def test_rotated_key_found_by_forced_refresh(
    clock: Clock, endpoint: KeyEndpoint, other_keypair: KeyPair
) -> None:
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    await source.get("test")
    endpoint.body = {"rotated": certificate_pem(other_keypair[0])}
    assert await source.get("rotated") is not None
    assert endpoint.requests == 2


async def test_owned_client_closed(clock: Clock) -> None:
    source = GoogleX509KeySource(clock=clock)
    await source.aclose()
    assert source._client.is_closed


async def test_borrowed_client_left_open(clock: Clock, endpoint: KeyEndpoint) -> None:
    client = endpoint.client()
    source = GoogleX509KeySource(client, clock=clock)
    await source.aclose()
    assert not client.is_closed
    await client.aclose()


async def test_static_key_source(keypair: KeyPair) -> None:
    source = StaticKeySource({"a": keypair[1]})
    assert await source.get("a") is keypair[1]
    assert await source.get("b") is None
