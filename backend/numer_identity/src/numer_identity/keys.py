import asyncio
import logging
import re
import time
from collections.abc import Callable, Mapping
from typing import Protocol

import httpx
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicKey
from cryptography.x509 import load_pem_x509_certificate

from numer_identity.errors import KeysUnavailable

GOOGLE_CERTS_URL = (
    "https://www.googleapis.com/robot/v1/metadata/x509/"
    "securetoken@system.gserviceaccount.com"
)

MIN_LIFETIME = 300.0
MAX_LIFETIME = 86400.0
DEFAULT_LIFETIME = 3600.0
STALE_GRACE = 86400.0
FORCED_REFRESH_INTERVAL = 60.0
FAILURE_BACKOFF = 30.0
REQUEST_TIMEOUT = 3.0

_MAX_AGE = re.compile(r"(?:^|,)\s*max-age\s*=\s*(\d+)\s*(?:,|$)", re.IGNORECASE)

logger = logging.getLogger(__name__)


class KeySource(Protocol):
    async def get(self, kid: str) -> RSAPublicKey | None: ...


class StaticKeySource:
    def __init__(self, keys: Mapping[str, RSAPublicKey]) -> None:
        self._keys = dict(keys)

    async def get(self, kid: str) -> RSAPublicKey | None:
        return self._keys.get(kid)


def parse_max_age(cache_control: str | None) -> float:
    if cache_control is None:
        return DEFAULT_LIFETIME
    match = _MAX_AGE.search(cache_control)
    if match is None:
        return DEFAULT_LIFETIME
    return min(max(float(match.group(1)), MIN_LIFETIME), MAX_LIFETIME)


def _parse_certificates(data: object) -> dict[str, RSAPublicKey]:
    if not isinstance(data, dict):
        raise TypeError("key document is not an object")
    keys: dict[str, RSAPublicKey] = {}
    for kid, pem in data.items():
        if not isinstance(kid, str) or not isinstance(pem, str):
            raise TypeError("key document entry is not a string")
        public_key = load_pem_x509_certificate(pem.encode()).public_key()
        if not isinstance(public_key, RSAPublicKey):
            raise TypeError("key is not rsa")
        keys[kid] = public_key
    return keys


class GoogleX509KeySource:
    def __init__(
        self,
        client: httpx.AsyncClient | None = None,
        url: str = GOOGLE_CERTS_URL,
        clock: Callable[[], float] = time.time,
    ) -> None:
        self._owns_client = client is None
        self._client = client if client is not None else httpx.AsyncClient()
        self._url = url
        self._clock = clock
        self._lock = asyncio.Lock()
        self._keys: dict[str, RSAPublicKey] = {}
        self._expires_at = 0.0
        self._retry_after = 0.0
        self._last_forced: float | None = None
        self._attempts = 0

    async def get(self, kid: str) -> RSAPublicKey | None:
        now = self._clock()
        if kid in self._keys and now < self._expires_at:
            return self._keys[kid]
        attempts_seen = self._attempts
        async with self._lock:
            now = self._clock()
            if now >= self._expires_at and now >= self._retry_after:
                await self._refresh(now)
            if (
                kid not in self._keys
                and self._attempts == attempts_seen
                and self._may_force(now)
            ):
                self._last_forced = now
                await self._refresh(now)
            if not self._keys or now > self._expires_at + STALE_GRACE:
                raise KeysUnavailable("no usable firebase public keys")
            return self._keys.get(kid)

    async def aclose(self) -> None:
        if self._owns_client:
            await self._client.aclose()

    def _may_force(self, now: float) -> bool:
        if now < self._retry_after:
            return False
        if self._last_forced is None:
            return True
        return now - self._last_forced >= FORCED_REFRESH_INTERVAL

    async def _refresh(self, now: float) -> None:
        self._attempts += 1
        try:
            response = await self._client.get(self._url, timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            keys = _parse_certificates(response.json())
        except (httpx.HTTPError, ValueError, TypeError) as error:
            self._retry_after = now + FAILURE_BACKOFF
            logger.warning("firebase key refresh failed: %s", type(error).__name__)
            return
        self._keys = keys
        self._expires_at = now + parse_max_age(response.headers.get("cache-control"))
