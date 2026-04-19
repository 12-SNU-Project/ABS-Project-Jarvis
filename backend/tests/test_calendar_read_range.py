from __future__ import annotations

from datetime import datetime

import pytest

from app.core.errors import AppError
from app.services.calendar_read import resolve_range


def test_default_timezone_changes_default_window_boundaries(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JARVIS_DEFAULT_DATE", "2026-04-18")
    monkeypatch.setenv("JARVIS_DEFAULT_TIMEZONE", "America/Los_Angeles")

    range_label, start_at, end_at = resolve_range(None, None, None)

    assert range_label == "2026-04-18"
    assert start_at.isoformat() == "2026-04-18T00:00:00-07:00"
    assert end_at.isoformat() == "2026-04-19T00:00:00-07:00"


def test_date_query_resolves_with_configured_timezone(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JARVIS_DEFAULT_TIMEZONE", "America/Los_Angeles")

    range_label, start_at, end_at = resolve_range("2026-04-18", None, None)

    assert range_label == "2026-04-18"
    assert start_at == datetime.fromisoformat("2026-04-18T00:00:00-07:00")
    assert end_at == datetime.fromisoformat("2026-04-19T00:00:00-07:00")


def test_start_end_date_range_resolves_with_configured_timezone(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JARVIS_DEFAULT_TIMEZONE", "America/Los_Angeles")

    range_label, start_at, end_at = resolve_range(None, "2026-04-18", "2026-04-19")

    assert range_label == "2026-04-18"
    assert start_at == datetime.fromisoformat("2026-04-18T00:00:00-07:00")
    assert end_at == datetime.fromisoformat("2026-04-20T00:00:00-07:00")


def test_invalid_date_still_raises_422_invalid_date(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("JARVIS_DEFAULT_TIMEZONE", "America/Los_Angeles")

    with pytest.raises(AppError) as exc_info:
        resolve_range("2026-02-30", None, None)

    assert exc_info.value.status_code == 422
    assert exc_info.value.code == "invalid_date"


def test_mixed_date_and_range_validation_is_unchanged() -> None:
    with pytest.raises(AppError) as exc_info:
        resolve_range("2026-04-18", "2026-04-18", "2026-04-19")

    assert exc_info.value.status_code == 422
    assert exc_info.value.code == "invalid_query"
