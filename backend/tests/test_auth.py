"""Tests for the authentication service."""

import pytest
from app.config import Settings
from app.services import auth_service


@pytest.fixture(autouse=True)
def reset_settings(monkeypatch):
    """Ensure a known API key for each test."""
    monkeypatch.setattr(auth_service, "get_settings", lambda: Settings(api_key="super-secret-key"))


def test_verify_api_key_valid():
    assert auth_service.verify_api_key("super-secret-key") is True


def test_verify_api_key_invalid():
    assert auth_service.verify_api_key("wrong-key") is False


def test_verify_api_key_none():
    assert auth_service.verify_api_key(None) is False


def test_verify_api_key_whitespace():
    assert auth_service.verify_api_key("  super-secret-key  ") is True
