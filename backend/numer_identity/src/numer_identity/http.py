from numer_identity.errors import TokenInvalid


def bearer_token(authorization: str | None) -> str:
    if authorization is None:
        raise TokenInvalid("malformed")
    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token or any(c.isspace() for c in token):
        raise TokenInvalid("malformed")
    return token
