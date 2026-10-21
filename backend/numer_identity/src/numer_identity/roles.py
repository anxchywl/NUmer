def parse_roles(value: object) -> frozenset[str]:
    if not isinstance(value, list):
        return frozenset()
    if not all(isinstance(item, str) for item in value):
        return frozenset()
    return frozenset(value)
