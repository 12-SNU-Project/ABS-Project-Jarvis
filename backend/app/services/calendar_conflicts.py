from __future__ import annotations

from typing import Any

from app.providers.calendar_provider import get_calendar, list_events, load_calendar_state
from app.services.calendar_read import (
    CALENDAR_BUFFER_MINUTES,
    base_calendar_payload,
    parse_datetime,
    resolve_range,
)


def detect_conflicts(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    conflicts: list[dict[str, Any]] = []
    sorted_events = sorted(events, key=lambda event: event["start"])
    for previous, current in zip(sorted_events, sorted_events[1:]):
        previous_end = parse_datetime(previous["end"])
        current_start = parse_datetime(current["start"])
        if current_start < previous_end:
            conflicts.append(
                {
                    "type": "overlap",
                    "message": f"'{previous['title']}' overlaps with '{current['title']}'.",
                    "severity": "high",
                    "event_ids": [previous["id"], current["id"]],
                }
            )
            continue

        gap_minutes = int((current_start - previous_end).total_seconds() // 60)
        if gap_minutes < CALENDAR_BUFFER_MINUTES:
            conflicts.append(
                {
                    "type": "tight_buffer",
                    "message": f"Only {gap_minutes} minutes separate '{previous['title']}' and '{current['title']}'.",
                    "severity": "medium",
                    "event_ids": [previous["id"], current["id"]],
                }
            )

    return conflicts


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
