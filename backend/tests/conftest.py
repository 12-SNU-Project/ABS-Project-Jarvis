from __future__ import annotations

from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


@pytest.fixture()
def client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    state_path = tmp_path / "calendar-state.json"
    monkeypatch.setenv("JARVIS_CALENDAR_STATE_PATH", str(state_path))
    monkeypatch.setenv("JARVIS_DEFAULT_DATE", "2026-04-18")
    monkeypatch.setenv("JARVIS_DEFAULT_TIMEZONE", "Asia/Seoul")

    from app.providers.calendar_provider import reset_calendar_state
    from main import app

    reset_calendar_state()

    with TestClient(app) as test_client:
        yield test_client
