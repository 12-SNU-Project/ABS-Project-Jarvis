from __future__ import annotations

import copy
import json
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any

from app.core.config import get_settings
from app.core.errors import AppError
from app.providers.mock_provider import load_mock


def _normalize_event(event: dict[str, Any]) -> dict[str, Any]:
    normalized = copy.deepcopy(event)
    normalized["description"] = normalized.get("description")
    normalized["location"] = normalized.get("location")
    normalized["priority"] = normalized.get("priority") or "medium"
    normalized["all_day"] = bool(normalized.get("all_day", False))
    normalized["recurring"] = bool(normalized.get("recurring", False))
    normalized["recurrence_rule"] = normalized.get("recurrence_rule")
    normalized["recurrence_interval_days"] = normalized.get("recurrence_interval_days")
    normalized["recurrence_count"] = normalized.get("recurrence_count")
    normalized["series_id"] = normalized.get("series_id")
    return normalized


def _normalize_state(state: dict[str, Any]) -> dict[str, Any]:
    normalized = copy.deepcopy(state)
    normalized["events"] = [_normalize_event(event) for event in normalized.get("events", [])]
    normalized.setdefault("calendars", [])
    normalized.setdefault("proposals", [])
    normalized.setdefault("audit_records", [])
    return normalized


def _parse_datetime(value: str) -> datetime:
    return datetime.fromisoformat(value)


def _state_path() -> Path:
    settings = get_settings()
    path = Path(settings.calendar_state_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    return path


def _combine_datetime(date_value: str, time_value: str, timezone: str) -> str:
    suffix = "+09:00" if timezone == "Asia/Seoul" else "+00:00"
    return f"{date_value}T{time_value}:00{suffix}"


def _build_seed_events() -> list[dict[str, Any]]:
    settings = get_settings()
    timezone = settings.default_timezone
    date_value = settings.default_date
    mock_data = load_mock("calendar")
    events: list[dict[str, Any]] = []

    for index, event in enumerate(mock_data["events"], start=1):
        events.append(
            {
                "id": f"evt-{index}",
                "calendar_id": "primary",
                "title": event["title"],
                "start": _combine_datetime(date_value, event["start"], timezone),
                "end": _combine_datetime(date_value, event["end"], timezone),
                "description": None,
                "location": event.get("location"),
                "priority": event.get("priority", "medium"),
                "all_day": False,
                "recurring": False,
                "recurrence_rule": None,
                "recurrence_interval_days": None,
                "recurrence_count": None,
                "series_id": None,
            }
        )

    recurring_series_id = "series-team-sync"
    base_start = datetime.fromisoformat(_combine_datetime(date_value, "17:00", timezone))
    base_end = datetime.fromisoformat(_combine_datetime(date_value, "17:30", timezone))
    for index in range(3):
        events.append(
            {
                "id": f"evt-series-{index + 1}",
                "calendar_id": "primary",
                "title": "Team Sync",
                "start": (base_start + timedelta(days=7 * index)).isoformat(),
                "end": (base_end + timedelta(days=7 * index)).isoformat(),
                "description": "Weekly recurring planning sync.",
                "location": "Zoom",
                "priority": "medium",
                "all_day": False,
                "recurring": True,
                "recurrence_rule": "FREQ=WEEKLY;COUNT=3",
                "recurrence_interval_days": 7,
                "recurrence_count": 3,
                "series_id": recurring_series_id,
            }
        )

    return events


def _default_state() -> dict[str, Any]:
    settings = get_settings()
    return {
        "calendars": [
            {
                "id": "primary",
                "name": "Primary Calendar",
                "timezone": settings.default_timezone,
                "is_primary": True,
                "uses_mock": True,
            }
        ],
        "events": _build_seed_events(),
        "proposals": [],
        "audit_records": [],
    }


def load_calendar_state() -> dict[str, Any]:
    path = _state_path()
    if not path.exists():
        state = _default_state()
        save_calendar_state(state)
        return state

    with path.open("r", encoding="utf-8") as file:
        state = json.load(file)

    normalized = _normalize_state(state)
    if normalized != state:
        save_calendar_state(normalized)
    return normalized


def save_calendar_state(state: dict[str, Any]) -> None:
    path = _state_path()
    normalized = _normalize_state(state)
    with path.open("w", encoding="utf-8") as file:
        json.dump(normalized, file, ensure_ascii=True, indent=2)


def reset_calendar_state() -> dict[str, Any]:
    state = _default_state()
    save_calendar_state(state)
    return state


def clone_state(state: dict[str, Any]) -> dict[str, Any]:
    return copy.deepcopy(state)


def list_calendars(state: dict[str, Any]) -> list[dict[str, Any]]:
    return sorted(state["calendars"], key=lambda calendar: calendar["id"])


def get_calendar(state: dict[str, Any], calendar_id: str) -> dict[str, Any]:
    for calendar in state["calendars"]:
        if calendar["id"] == calendar_id:
            return copy.deepcopy(calendar)
    raise AppError(code="calendar_not_found", message=f"Calendar '{calendar_id}' not found.", status_code=404)


def list_events(state: dict[str, Any], calendar_id: str, start_at: datetime, end_at: datetime) -> list[dict[str, Any]]:
    get_calendar(state, calendar_id)
    events = []
    for event in state["events"]:
        if event["calendar_id"] != calendar_id:
            continue
        event_start = _parse_datetime(event["start"])
        event_end = _parse_datetime(event["end"])
        if event_end > start_at and event_start < end_at:
            events.append(_normalize_event(event))
    return sorted(events, key=lambda event: event["start"])


def get_event(state: dict[str, Any], calendar_id: str, event_id: str) -> dict[str, Any]:
    for event in state["events"]:
        if event["calendar_id"] == calendar_id and event["id"] == event_id:
            return _normalize_event(event)
    raise AppError(code="event_not_found", message=f"Event '{event_id}' not found in calendar '{calendar_id}'.", status_code=404)


def _event_indexes_for_scope(
    state: dict[str, Any],
    calendar_id: str,
    event_id: str,
    recurring_scope: str | None,
) -> list[int]:
    target_index = -1
    target_event: dict[str, Any] | None = None
    for index, event in enumerate(state["events"]):
        if event["calendar_id"] == calendar_id and event["id"] == event_id:
            target_index = index
            target_event = event
            break

    if target_event is None:
        raise AppError(code="event_not_found", message=f"Event '{event_id}' not found in calendar '{calendar_id}'.", status_code=404)

    if not target_event["recurring"]:
        return [target_index]

    if recurring_scope is None:
        raise AppError(
            code="recurring_scope_required",
            message="Recurring event operations require an explicit scope.",
            status_code=422,
        )

    series_id = target_event["series_id"]
    if not series_id:
        return [target_index]

    target_start = _parse_datetime(target_event["start"])
    indexes: list[int] = []
    for index, event in enumerate(state["events"]):
        if event["calendar_id"] != calendar_id or event.get("series_id") != series_id:
            continue
        event_start = _parse_datetime(event["start"])
        if recurring_scope == "occurrence" and event["id"] == event_id:
            indexes.append(index)
        elif recurring_scope == "following" and event_start >= target_start:
            indexes.append(index)
        elif recurring_scope == "series":
            indexes.append(index)

    return indexes or [target_index]


def create_event(state: dict[str, Any], calendar_id: str, payload: dict[str, Any]) -> list[dict[str, Any]]:
    calendar = get_calendar(state, calendar_id)
    created_events: list[dict[str, Any]] = []
    series_id = payload.get("series_id") or (str(uuid.uuid4()) if payload.get("recurring") else None)
    recurrence_count = payload.get("recurrence_count") or 1
    recurrence_interval_days = payload.get("recurrence_interval_days") or 7
    base_start = _parse_datetime(payload["start"])
    base_end = _parse_datetime(payload["end"])

    for index in range(recurrence_count):
        event = {
            "id": f"evt-{uuid.uuid4().hex[:12]}",
            "calendar_id": calendar["id"],
            "title": payload["title"],
            "start": (base_start + timedelta(days=index * recurrence_interval_days)).isoformat(),
            "end": (base_end + timedelta(days=index * recurrence_interval_days)).isoformat(),
            "description": payload.get("description"),
            "location": payload.get("location"),
            "priority": payload.get("priority") or "medium",
            "all_day": payload.get("all_day", False),
            "recurring": payload.get("recurring", False),
            "recurrence_rule": payload.get("recurrence_rule"),
            "recurrence_interval_days": recurrence_interval_days if payload.get("recurring") else None,
            "recurrence_count": recurrence_count if payload.get("recurring") else None,
            "series_id": series_id if payload.get("recurring") else None,
        }
        state["events"].append(event)
        created_events.append(_normalize_event(event))

    return created_events


def update_event(
    state: dict[str, Any],
    calendar_id: str,
    event_id: str,
    payload: dict[str, Any],
    recurring_scope: str | None = None,
) -> list[dict[str, Any]]:
    indexes = _event_indexes_for_scope(state, calendar_id, event_id, recurring_scope)
    updated_events: list[dict[str, Any]] = []
    for index in indexes:
        for key, value in payload.items():
            if value is not None:
                state["events"][index][key] = value
        updated_events.append(_normalize_event(state["events"][index]))
    return updated_events


def _resolve_move_bounds(
    event: dict[str, Any],
    payload: dict[str, Any],
) -> tuple[datetime | None, datetime | None]:
    new_start = _parse_datetime(payload["start"]) if payload.get("start") else None
    new_end = _parse_datetime(payload["end"]) if payload.get("end") else None
    if new_start is None and new_end is None:
        return None, None

    original_start = _parse_datetime(event["start"])
    original_end = _parse_datetime(event["end"])
    duration = original_end - original_start

    if new_start is None:
        new_start = new_end - duration
    if new_end is None:
        new_end = new_start + duration

    return new_start, new_end


def move_event(
    state: dict[str, Any],
    calendar_id: str,
    event_id: str,
    payload: dict[str, Any],
    recurring_scope: str | None = None,
) -> list[dict[str, Any]]:
    indexes = _event_indexes_for_scope(state, calendar_id, event_id, recurring_scope)
    target_event = get_event(state, calendar_id, event_id)
    target_start = _parse_datetime(target_event["start"])
    target_end = _parse_datetime(target_event["end"])
    new_start, new_end = _resolve_move_bounds(target_event, payload)
    start_delta = (new_start - target_start) if new_start is not None else None
    end_delta = (new_end - target_end) if new_end is not None else None
    shift_series = target_event["recurring"] and recurring_scope in {"following", "series"}

    updated_events: list[dict[str, Any]] = []
    for index in indexes:
        current_event = state["events"][index]
        current_start = _parse_datetime(current_event["start"])
        current_end = _parse_datetime(current_event["end"])

        for key, value in payload.items():
            if key in {"start", "end"} or value is None:
                continue
            current_event[key] = value

        if new_start is not None:
            current_event["start"] = (
                current_start + start_delta if shift_series else new_start
            ).isoformat()
        if new_end is not None:
            current_event["end"] = (
                current_end + end_delta if shift_series else new_end
            ).isoformat()

        updated_events.append(_normalize_event(current_event))

    return updated_events


def delete_event(
    state: dict[str, Any],
    calendar_id: str,
    event_id: str,
    recurring_scope: str | None = None,
) -> list[dict[str, Any]]:
    indexes = sorted(_event_indexes_for_scope(state, calendar_id, event_id, recurring_scope), reverse=True)
    deleted_events: list[dict[str, Any]] = []
    for index in indexes:
        deleted_events.append(_normalize_event(state["events"][index]))
        del state["events"][index]
    return list(reversed(deleted_events))


def create_calendar(state: dict[str, Any], payload: dict[str, Any]) -> dict[str, Any]:
    calendar = {
        "id": f"cal-{uuid.uuid4().hex[:12]}",
        "name": payload["name"],
        "timezone": payload.get("timezone", "Asia/Seoul"),
        "is_primary": payload.get("is_primary", False),
        "uses_mock": True,
    }
    state["calendars"].append(calendar)
    return copy.deepcopy(calendar)


def delete_calendar(state: dict[str, Any], calendar_id: str) -> dict[str, Any]:
    if calendar_id == "primary":
        raise AppError(
            code="primary_calendar_protected",
            message="The primary calendar cannot be deleted in mock mode.",
            status_code=409,
        )

    for index, calendar in enumerate(state["calendars"]):
        if calendar["id"] == calendar_id:
            deleted_calendar = copy.deepcopy(calendar)
            del state["calendars"][index]
            state["events"] = [event for event in state["events"] if event["calendar_id"] != calendar_id]
            return deleted_calendar

    raise AppError(code="calendar_not_found", message=f"Calendar '{calendar_id}' not found.", status_code=404)


def list_proposals(state: dict[str, Any]) -> list[dict[str, Any]]:
    return sorted(copy.deepcopy(state["proposals"]), key=lambda proposal: proposal["created_at"], reverse=True)


def get_proposal(state: dict[str, Any], proposal_id: str) -> dict[str, Any]:
    for proposal in state["proposals"]:
        if proposal["proposal_id"] == proposal_id:
            return copy.deepcopy(proposal)
    raise AppError(code="proposal_not_found", message=f"Proposal '{proposal_id}' not found.", status_code=404)


def store_proposal(state: dict[str, Any], proposal: dict[str, Any]) -> dict[str, Any]:
    state["proposals"].append(copy.deepcopy(proposal))
    return proposal


def replace_proposal(state: dict[str, Any], proposal_id: str, updated_proposal: dict[str, Any]) -> dict[str, Any]:
    for index, proposal in enumerate(state["proposals"]):
        if proposal["proposal_id"] == proposal_id:
            state["proposals"][index] = copy.deepcopy(updated_proposal)
            return updated_proposal
    raise AppError(code="proposal_not_found", message=f"Proposal '{proposal_id}' not found.", status_code=404)


def append_audit_record(state: dict[str, Any], record: dict[str, Any]) -> dict[str, Any]:
    state["audit_records"].append(copy.deepcopy(record))
    return record


def list_audit_records(state: dict[str, Any]) -> list[dict[str, Any]]:
    return sorted(copy.deepcopy(state["audit_records"]), key=lambda record: record["recorded_at"], reverse=True)
