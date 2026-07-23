"""Authentication helpers."""

import secrets

from ..config import get_settings


def verify_api_key(provided_key: str | None) -> bool:
    """Constant-time compare the provided API key with the configured key.

    Args:
        provided_key: The API key supplied by the client.

    Returns:
        True if the key is valid, False otherwise.
    """
    if not provided_key:
        return False
    expected = get_settings().api_key
    return secrets.compare_digest(provided_key.strip(), expected.strip())
