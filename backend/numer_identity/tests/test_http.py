import pytest

from numer_identity import TokenInvalid, bearer_token, parse_roles


@pytest.mark.parametrize(
    ("header", "token"),
    [("Bearer abc.def.ghi", "abc.def.ghi"), ("bearer x", "x"), ("BEARER x", "x")],
)
def test_bearer_token_accepted(header: str, token: str) -> None:
    assert bearer_token(header) == token


@pytest.mark.parametrize(
    "header",
    [None, "", "Bearer", "Bearer ", "Basic abc", "Token abc", "Bearer a b", "abc"],
)
def test_bearer_token_rejected(header: str | None) -> None:
    with pytest.raises(TokenInvalid) as caught:
        bearer_token(header)
    assert caught.value.code == "malformed"


@pytest.mark.parametrize(
    ("value", "roles"),
    [
        (["a:b", "c:d"], frozenset({"a:b", "c:d"})),
        ([], frozenset()),
        (["a:b", None], frozenset()),
        ("a:b", frozenset()),
        ({"a:b": True}, frozenset()),
        (None, frozenset()),
    ],
)
def test_parse_roles(value: object, roles: frozenset[str]) -> None:
    assert parse_roles(value) == roles
