from __future__ import annotations

import hashlib
import json
from copy import deepcopy
from datetime import UTC, date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from app.core.config import get_settings
from app.core.errors import AppError
from app.providers.calendar_provider import (
    get_calendar,
    list_calendars,
    list_events,
    load_calendar_state,
)


CALENDAR_OWNER = ""
CALENDAR_FEATURE = "calendar"
CALENDAR_BUFFER_MINUTES = 30


def parse_datetime(value: str) -> datetime:
    try:
        return datetime.fromisoformat(value)
    except ValueError as exc:
        raise AppError(
            code="invalid_datetime",
            message=f"Invalid datetime value '{value}'.",
            status_code=422,
        ) from exc


def parse_date(value: str) -> datetime:
    try:
        parsed_date = date.fromisoformat(value)
    except ValueError as exc:
        raise AppError(
            code="invalid_date",
            message=f"Invalid date value '{value}'.",
            status_code=422,
        ) from exc
    return datetime.combine(parsed_date, time.min, tzinfo=ZoneInfo(get_settings().default_timezone))


def current_timestamp() -> str:
    return datetime.now(UTC).isoformat()


def calendar_snapshot_hash(state: dict[str, Any]) -> str:
    payload = json.dumps(deepcopy(state), sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def schedule_snapshot_hash(state: dict[str, Any]) -> str:
    return calendar_snapshot_hash({"calendars": state["calendars"], "events": state["events"]})


def resolve_range(
    date_value: str | None,
    start_date: str | None,
    end_date: str | None,
) -> tuple[str, datetime, datetime]:
    if date_value and (start_date or end_date):
        raise AppError(
            code="invalid_query",
            message="Use either date or start_date/end_date, not both.",
            status_code=422,
        )

    if bool(start_date) != bool(end_date):
        raise AppError(
            code="invalid_query",
            message="start_date and end_date must be provided together.",
            status_code=422,
        )

    if date_value:
        start_at = parse_date(date_value)
        return date_value, start_at, start_at + timedelta(days=1)

    if start_date and end_date:
        start_at = parse_date(start_date)
        end_at = parse_date(end_date) + timedelta(days=1)
        if end_at <= start_at:
            raise AppError(
                code="invalid_query",
                message="end_date must be on or after start_date.",
                status_code=422,
            )
        return start_date, start_at, end_at

    default_date = get_settings().default_date
    start_at = parse_date(default_date)
    return default_date, start_at, start_at + timedelta(days=1)


def base_calendar_payload() -> dict[str, Any]:
    return {"owner": CALENDAR_OWNER, "feature": CALENDAR_FEATURE, "uses_mock": True}


def list_calendars_response() -> dict[str, Any]:
    state = load_calendar_state()
    return {**base_calendar_payload(), "calendars": list_calendars(state)}


def get_calendar_detail_response(calendar_id: str) -> dict[str, Any]:
    state = load_calendar_state()
    return {**base_calendar_payload(), "calendar": get_calendar(state, calendar_id)}


def get_calendar_events_response(
    calendar_id: str,
    *,
    date_value: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
) -> dict[str, Any]:
    state = load_calendar_state()
    range_label, start_at, end_at = resolve_range(date_value, start_date, end_date)
    return {
        **base_calendar_payload(),
        "calendar": get_calendar(state, calendar_id),
        "events": list_events(state, calendar_id, start_at, end_at),
        "range_label": range_label,
    }


def get_calendar_brief(date: str, calendar_id: str = "primary") -> dict[str, Any]:
    from .conflicts import get_calendar_summary_response

    summary = get_calendar_summary_response(calendar_id, date_value=date)
    return {
        **base_calendar_payload(),
        "calendar_id": calendar_id,
        "date": summary["date"],
        "summary": summary["summary"],
        "events": summary["events"],
        "conflicts": summary["conflicts"],
    }
