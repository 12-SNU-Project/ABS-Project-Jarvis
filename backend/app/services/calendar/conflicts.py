from __future__ import annotations

from datetime import timedelta
from typing import Any

from app.providers.calendar_provider import get_calendar, list_events, load_calendar_state

from .read import (
    CALENDAR_BUFFER_MINUTES,
    base_calendar_payload,
    parse_datetime,
    resolve_range,
)


def _sorted_calendar_events(events: list[dict[str, Any]]) -> list[tuple[Any, Any, dict[str, Any]]]:
    sorted_events: list[tuple[Any, Any, dict[str, Any]]] = []
    for event in events:
        sorted_events.append((parse_datetime(event["start"]), parse_datetime(event["end"]), event))

    sorted_events.sort(
        key=lambda item: (
            item[0],
            item[1],
            str(item[2].get("id", "")),
            str(item[2].get("title", "")),
        )
    )
    return sorted_events


def _build_conflict(
    left_event: dict[str, Any],
    right_event: dict[str, Any],
    *,
    conflict_type: str,
    gap_minutes: int | None = None,
) -> dict[str, Any]:
    if conflict_type == "overlap":
        return {
            "type": "overlap",
            "message": f"'{left_event['title']}' overlaps with '{right_event['title']}'.",
            "severity": "high",
            "event_ids": [left_event["id"], right_event["id"]],
        }

    return {
        "type": "tight_buffer",
        "message": f"Only {gap_minutes} minutes separate '{left_event['title']}' and '{right_event['title']}'.",
        "severity": "medium",
        "event_ids": [left_event["id"], right_event["id"]],
    }


def _conflict_rank(conflict_type: str) -> int:
    if conflict_type == "overlap":
        return 2
    if conflict_type == "tight_buffer":
        return 1
    return 0


def detect_conflicts(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    conflicts_by_pair: dict[tuple[str, str], dict[str, Any]] = {}
    sorted_events = _sorted_calendar_events(events)

    for index, (_, event_end, event) in enumerate(sorted_events):
        compare_until = event_end + timedelta(minutes=CALENDAR_BUFFER_MINUTES)
        for next_start, _, next_event in sorted_events[index + 1 :]:
            if next_start >= compare_until:
                break

            pair_key = (str(event["id"]), str(next_event["id"]))
            gap_minutes = int((next_start - event_end).total_seconds() // 60)
            if gap_minutes < 0:
                conflict = _build_conflict(event, next_event, conflict_type="overlap")
            elif gap_minutes < CALENDAR_BUFFER_MINUTES:
                conflict = _build_conflict(
                    event,
                    next_event,
                    conflict_type="tight_buffer",
                    gap_minutes=gap_minutes,
                )
            else:
                continue

            existing = conflicts_by_pair.get(pair_key)
            if existing is None or _conflict_rank(conflict["type"]) > _conflict_rank(existing["type"]):
                conflicts_by_pair[pair_key] = conflict

    return list(conflicts_by_pair.values())


def build_summary(
    events: list[dict[str, Any]],
    conflicts: list[dict[str, Any]],
    range_label: str,
) -> str:
    if not events:
        return f"No scheduled events found for {range_label}."

    high_priority = sum(1 for event in events if event.get("priority") == "high")
    summary = (
        f"{len(events)} scheduled event(s) for {range_label}, "
        f"including {high_priority} high-priority item(s)."
    )
    if conflicts:
        summary += f" {len(conflicts)} conflict warning(s) need attention."
    else:
        summary += " No timing conflicts detected."
    return summary


def get_calendar_conflicts_response(
    calendar_id: str,
    *,
    date_value: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
) -> dict[str, Any]:
    state = load_calendar_state()
    _, start_at, end_at = resolve_range(date_value, start_date, end_date)
    events = list_events(state, calendar_id, start_at, end_at)
    return {
        **base_calendar_payload(),
        "calendar": get_calendar(state, calendar_id),
        "conflicts": detect_conflicts(events),
    }


def get_calendar_summary_response(
    calendar_id: str,
    *,
    date_value: str | None = None,
    start_date: str | None = None,
    end_date: str | None = None,
) -> dict[str, Any]:
    state = load_calendar_state()
    range_label, start_at, end_at = resolve_range(date_value, start_date, end_date)
    events = list_events(state, calendar_id, start_at, end_at)
    conflicts = detect_conflicts(events)
    return {
        **base_calendar_payload(),
        "calendar": get_calendar(state, calendar_id),
        "date": range_label,
        "summary": build_summary(events, conflicts, range_label),
        "events": events,
        "conflicts": conflicts,
    }
