import datetime
import json
from collections.abc import Callable
from dataclasses import dataclass, field

import httpx
import pytest
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric.ec import EllipticCurvePrivateKey
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPrivateKey, RSAPublicKey
from cryptography.x509.oid import NameOID

from numer_identity.testing import make_test_keypair

PROJECT = "numer-test"
NOW = 1_800_000_000.0


class Clock:
    def __init__(self, now: float = NOW) -> None:
        self.now = now

    def __call__(self) -> float:
        return self.now


def certificate_pem(private_key: RSAPrivateKey | EllipticCurvePrivateKey) -> str:
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "test")])
    start = datetime.datetime(2020, 1, 1, tzinfo=datetime.UTC)
    certificate = (
        x509.CertificateBuilder()
        .subject_name(name)
        .issuer_name(name)
        .public_key(private_key.public_key())
        .serial_number(1)
        .not_valid_before(start)
        .not_valid_after(start + datetime.timedelta(days=3650))
        .sign(private_key, hashes.SHA256())
    )
    return certificate.public_bytes(serialization.Encoding.PEM).decode()


@dataclass
class KeyEndpoint:
    body: dict[str, str]
    status: int = 200
    cache_control: str | None = "public, max-age=3600"
    requests: int = 0
    raw: bytes | None = None
    on_request: Callable[[], None] = field(default=lambda: None)

    async def handle(self, request: httpx.Request) -> httpx.Response:
        self.requests += 1
        self.on_request()
        headers = (
            {} if self.cache_control is None else {"cache-control": self.cache_control}
        )
        content = self.raw if self.raw is not None else json.dumps(self.body).encode()
        return httpx.Response(self.status, headers=headers, content=content)

    def client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(transport=httpx.MockTransport(self.handle))


@pytest.fixture(scope="session")
def keypair() -> tuple[RSAPrivateKey, RSAPublicKey]:
    return make_test_keypair()


@pytest.fixture(scope="session")
def other_keypair() -> tuple[RSAPrivateKey, RSAPublicKey]:
    return make_test_keypair()


@pytest.fixture(scope="session")
def cert_pem(keypair: tuple[RSAPrivateKey, RSAPublicKey]) -> str:
    return certificate_pem(keypair[0])


@pytest.fixture
def clock() -> Clock:
    return Clock()


@pytest.fixture
def endpoint(cert_pem: str) -> KeyEndpoint:
    return KeyEndpoint(body={"test": cert_pem})
