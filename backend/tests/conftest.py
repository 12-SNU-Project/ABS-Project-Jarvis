from __future__ import annotations

from collections.abc import Iterator
import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient


BACKEND_ROOT = Path(__file__).resolve().parents[1]

if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))


os.environ["JARVIS_USE_MOCKS"] = "true"


@pytest.fixture()
def client(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[TestClient]:
    state_path = tmp_path / "calendar-state.json"
    monkeypatch.setenv("JARVIS_CALENDAR_STATE_PATH", str(state_path))
    monkeypatch.setenv("JARVIS_DEFAULT_DATE", "2026-04-18")
    monkeypatch.setenv("JARVIS_DEFAULT_TIMEZONE", "Asia/Seoul")
    monkeypatch.setenv("JARVIS_USE_MOCKS", "true")

    from app.providers.calendar_provider import reset_calendar_state
    from main import app

    reset_calendar_state()

    with TestClient(app) as test_client:
        yield test_client
