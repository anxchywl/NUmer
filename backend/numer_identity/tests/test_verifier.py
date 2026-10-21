import asyncio
from typing import Any

import jwt
import pytest
from conftest import NOW, PROJECT, Clock, KeyEndpoint
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey, RSAPublicKey

from numer_identity import (
    FirebaseClaims,
    FirebaseVerifier,
    GoogleX509KeySource,
    KeysUnavailable,
    StaticKeySource,
    TokenInvalid,
)
from numer_identity.testing import (
    hs256_token,
    sign_token,
    unsigned_token,
    valid_claims,
)

KeyPair = tuple[RSAPrivateKey, RSAPublicKey]


def make_verifier(keypair: KeyPair, clock: Clock, **options: Any) -> FirebaseVerifier:
    return FirebaseVerifier(
        project_id=PROJECT,
        key_source=StaticKeySource({"test": keypair[1]}),
        clock=clock,
        **options,
    )


def token(keypair: KeyPair, now: float = NOW, **overrides: Any) -> str:
    return sign_token(valid_claims(PROJECT, "uid-1", now, **overrides), keypair[0])


async def expect(verifier: FirebaseVerifier, raw: Any, code: str) -> None:
    with pytest.raises(TokenInvalid) as caught:
        await verifier.verify(raw)
    assert caught.value.code == code


async def test_v01_valid_token(keypair: KeyPair, clock: Clock) -> None:
    claims = await make_verifier(keypair, clock).verify(token(keypair))
    assert claims.uid == "uid-1"
    assert claims.issuer == f"https://securetoken.google.com/{PROJECT}"
    assert claims.email == "student@nu.edu.kz"
    assert claims.email_verified is True
    assert claims.name == "Test User"
    assert claims.sign_in_provider == "password"
    assert claims.issued_at == claims.auth_time == int(NOW)
    assert claims.expires_at == int(NOW) + 3600
    assert claims.roles == frozenset()
    assert claims.raw["sub"] == "uid-1"


async def test_v02_alg_none(keypair: KeyPair, clock: Clock) -> None:
    raw = unsigned_token(valid_claims(PROJECT, "uid-1", NOW), kid="test")
    await expect(make_verifier(keypair, clock), raw, "algorithm")


async def test_v03_hs256_key_confusion(keypair: KeyPair, clock: Clock) -> None:
    pem = keypair[1].public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo
    )
    raw = hs256_token(valid_claims(PROJECT, "uid-1", NOW), pem, kid="test")
    await expect(make_verifier(keypair, clock), raw, "algorithm")


async def test_v04_signed_by_other_key(
    keypair: KeyPair, other_keypair: KeyPair, clock: Clock
) -> None:
    raw = sign_token(valid_claims(PROJECT, "uid-1", NOW), other_keypair[0])
    await expect(make_verifier(keypair, clock), raw, "signature")


async def test_v05_unknown_kid_refreshes_once(
    keypair: KeyPair, clock: Clock, endpoint: KeyEndpoint
) -> None:
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    verifier = FirebaseVerifier(project_id=PROJECT, key_source=source, clock=clock)
    await verifier.verify(token(keypair))
    assert endpoint.requests == 1
    unknown = sign_token(valid_claims(PROJECT, "uid-1", NOW), keypair[0], kid="new")
    await expect(verifier, unknown, "unknown-key")
    assert endpoint.requests == 2
    clock.now += 59
    await expect(verifier, unknown, "unknown-key")
    assert endpoint.requests == 2
    clock.now += 1
    await expect(verifier, unknown, "unknown-key")
    assert endpoint.requests == 3
    await source.aclose()


async def test_v05_unknown_kid_on_cold_cache_loads_once(
    keypair: KeyPair, clock: Clock, endpoint: KeyEndpoint
) -> None:
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    verifier = FirebaseVerifier(project_id=PROJECT, key_source=source, clock=clock)
    unknown = sign_token(valid_claims(PROJECT, "uid-1", NOW), keypair[0], kid="new")
    await expect(verifier, unknown, "unknown-key")
    assert endpoint.requests == 1
    await expect(verifier, unknown, "unknown-key")
    assert endpoint.requests == 2


async def test_v06_audience_of_other_project(keypair: KeyPair, clock: Clock) -> None:
    raw = token(keypair, aud="other-project")
    await expect(make_verifier(keypair, clock), raw, "audience")


async def test_v07_issuer_of_other_project(keypair: KeyPair, clock: Clock) -> None:
    raw = token(keypair, iss="https://securetoken.google.com/other-project")
    await expect(make_verifier(keypair, clock), raw, "issuer")


async def test_v08_audience_missing(keypair: KeyPair, clock: Clock) -> None:
    await expect(make_verifier(keypair, clock), token(keypair, aud=None), "audience")


async def test_v09_expiry_and_leeway(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock)
    await expect(verifier, token(keypair, exp=int(NOW) - 31), "expired")
    claims = await verifier.verify(token(keypair, exp=int(NOW) - 20))
    assert claims.uid == "uid-1"


async def test_v10_iat_in_future(keypair: KeyPair, clock: Clock) -> None:
    raw = token(keypair, iat=int(NOW) + 120)
    await expect(make_verifier(keypair, clock), raw, "not-yet-valid")


async def test_v11_auth_time(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock)
    await expect(verifier, token(keypair, auth_time=None), "auth-time")
    await expect(verifier, token(keypair, auth_time=int(NOW) + 120), "auth-time")


async def test_v12_subject(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock)
    await expect(verifier, token(keypair, sub=""), "subject")
    await expect(verifier, token(keypair, sub="a" * 129), "subject")
    claims = await verifier.verify(token(keypair, sub="a" * 128))
    assert claims.uid == "a" * 128


async def test_v13_email_not_verified(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock)
    await expect(verifier, token(keypair, email_verified=False), "email-not-verified")
    await expect(verifier, token(keypair, email_verified="true"), "email-not-verified")


async def test_v14_provider_and_tenant(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock)
    anonymous = token(keypair, firebase={"sign_in_provider": "anonymous"})
    await expect(verifier, anonymous, "provider")
    custom = token(keypair, firebase={"sign_in_provider": "custom"})
    await expect(verifier, custom, "provider")
    tenant = token(keypair, firebase={"sign_in_provider": "password", "tenant": "t"})
    await expect(verifier, tenant, "tenant")


async def test_v15_revocation_check_propagates(keypair: KeyPair, clock: Clock) -> None:
    class Revoked(Exception):
        pass

    seen: list[FirebaseClaims] = []

    async def revoked(claims: FirebaseClaims) -> None:
        seen.append(claims)
        raise Revoked

    verifier = make_verifier(keypair, clock, revocation_check=revoked)
    with pytest.raises(Revoked):
        await verifier.verify(token(keypair))
    assert seen[0].uid == "uid-1"


async def test_v16_unverified_email_allowed_when_not_required(
    keypair: KeyPair, clock: Clock
) -> None:
    verifier = make_verifier(keypair, clock, require_verified_email=False)
    claims = await verifier.verify(token(keypair, email_verified=False))
    assert claims.email_verified is False


async def test_v17_roles(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock)
    for value in (["muto:admin", 7], "muto:admin", None):
        claims = await verifier.verify(token(keypair, numer_roles=value))
        assert claims.roles == frozenset()
    claims = await verifier.verify(token(keypair, numer_roles=["muto:admin"]))
    assert claims.roles == frozenset({"muto:admin"})


async def test_v17_custom_roles_claim(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock, roles_claim="roles")
    claims = await verifier.verify(token(keypair, roles=["events:admin"]))
    assert claims.roles == frozenset({"events:admin"})


async def test_v18_endpoint_down_with_warm_cache(
    keypair: KeyPair, clock: Clock, endpoint: KeyEndpoint
) -> None:
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    verifier = FirebaseVerifier(project_id=PROJECT, key_source=source, clock=clock)
    await verifier.verify(token(keypair))
    endpoint.status = 500
    clock.now += 3600
    claims = await verifier.verify(token(keypair, now=clock.now))
    assert claims.uid == "uid-1"
    assert endpoint.requests == 2


async def test_v18_endpoint_down_with_cold_cache(
    keypair: KeyPair, clock: Clock, endpoint: KeyEndpoint
) -> None:
    endpoint.status = 500
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    verifier = FirebaseVerifier(project_id=PROJECT, key_source=source, clock=clock)
    with pytest.raises(KeysUnavailable):
        await verifier.verify(token(keypair))


async def test_v19_size_and_segments(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock)
    await expect(verifier, "a" * 5000, "too-large")
    await expect(verifier, "aaa.bbb", "malformed")


async def test_v20_concurrent_cold_cache(
    keypair: KeyPair, clock: Clock, endpoint: KeyEndpoint
) -> None:
    source = GoogleX509KeySource(endpoint.client(), clock=clock)
    verifier = FirebaseVerifier(project_id=PROJECT, key_source=source, clock=clock)
    raw = token(keypair)
    results = await asyncio.gather(*(verifier.verify(raw) for _ in range(50)))
    assert {claims.uid for claims in results} == {"uid-1"}
    assert endpoint.requests == 1


async def test_non_string_token(keypair: KeyPair, clock: Clock) -> None:
    await expect(make_verifier(keypair, clock), 42, "malformed")


async def test_unparsable_header(keypair: KeyPair, clock: Clock) -> None:
    await expect(make_verifier(keypair, clock), "!!!.e30.sig", "malformed")


async def test_missing_kid(keypair: KeyPair, clock: Clock) -> None:
    raw = sign_token(
        valid_claims(PROJECT, "uid-1", NOW), keypair[0], kid="", headers={}
    )
    await expect(make_verifier(keypair, clock), raw, "malformed")


async def test_undecodable_payload(keypair: KeyPair, clock: Clock) -> None:
    header = token(keypair).split(".")[0]
    await expect(make_verifier(keypair, clock), f"{header}.!!!.sig", "malformed")


async def test_payload_not_json(keypair: KeyPair, clock: Clock) -> None:
    raw = jwt.api_jws.encode(b"not json", keypair[0], "RS256", {"kid": "test"})
    await expect(make_verifier(keypair, clock), raw, "malformed")


async def test_missing_exp(keypair: KeyPair, clock: Clock) -> None:
    await expect(make_verifier(keypair, clock), token(keypair, exp=None), "expired")


async def test_non_numeric_exp(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock)
    await expect(verifier, token(keypair, exp="soon"), "expired")
    await expect(verifier, token(keypair, exp=True), "expired")


async def test_missing_iat(keypair: KeyPair, clock: Clock) -> None:
    raw = token(keypair, iat=None)
    await expect(make_verifier(keypair, clock), raw, "not-yet-valid")


async def test_missing_sign_in_provider(keypair: KeyPair, clock: Clock) -> None:
    verifier = make_verifier(keypair, clock)
    await expect(verifier, token(keypair, firebase={"identities": {}}), "provider")
    await expect(verifier, token(keypair, firebase=None), "provider")


async def test_non_string_profile_fields(keypair: KeyPair, clock: Clock) -> None:
    claims = await make_verifier(keypair, clock).verify(token(keypair, email=None))
    assert claims.email is None


async def test_empty_project_id_rejected() -> None:
    with pytest.raises(ValueError):
        FirebaseVerifier(project_id="", key_source=StaticKeySource({}))


async def test_repr_hides_personal_data(keypair: KeyPair, clock: Clock) -> None:
    claims = await make_verifier(keypair, clock).verify(token(keypair))
    text = repr(claims)
    assert "student@nu.edu.kz" not in text
    assert "Test User" not in text
    assert "uid-1" in text
