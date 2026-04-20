from __future__ import annotations

from collections.abc import Iterator
import os
import sys
from pathlib import Path
import types

import pytest
from fastapi.testclient import TestClient


BACKEND_ROOT = Path(__file__).resolve().parents[1]

if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))


if "slack_sdk" not in sys.modules:
    slack_sdk_module = types.ModuleType("slack_sdk")

    class _StubWebClient:
        def __init__(self, *_args, **_kwargs) -> None:
            pass

    slack_sdk_module.WebClient = _StubWebClient
    sys.modules["slack_sdk"] = slack_sdk_module

if "slack_sdk.errors" not in sys.modules:
    slack_sdk_errors_module = types.ModuleType("slack_sdk.errors")

    class _StubSlackApiError(Exception):
        def __init__(self, message: str = "", response: dict | None = None) -> None:
            super().__init__(message)
            self.response = response or {}

    slack_sdk_errors_module.SlackApiError = _StubSlackApiError
    sys.modules["slack_sdk.errors"] = slack_sdk_errors_module


os.environ["JARVIS_USE_MOCKS"] = "true"


@pytest.fixture()
def client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    state_path = tmp_path / "calendar-state.json"
    samsung_health_state_path = tmp_path / "samsung-health-state.json"
    monkeypatch.setenv("JARVIS_CALENDAR_STATE_PATH", str(state_path))
    monkeypatch.setenv("SAMSUNG_HEALTH_STATE_PATH", str(samsung_health_state_path))
    monkeypatch.setenv("JARVIS_DEFAULT_DATE", "2026-04-18")
    monkeypatch.setenv("JARVIS_DEFAULT_TIMEZONE", "Asia/Seoul")
    monkeypatch.setenv("JARVIS_USE_MOCKS", "true")
    monkeypatch.setenv("SAMSUNG_HEALTH_BRIDGE_TOKEN", "bridge-test-token")

    from app.providers.calendar_provider import reset_calendar_state
    from app.providers.samsung_health_state_provider import reset_samsung_health_state
    from main import app

    reset_calendar_state()
    reset_samsung_health_state()

    with TestClient(app) as test_client:
        yield test_client
