from __future__ import annotations

import uuid
from typing import Any

from app.core.errors import AppError
from app.providers.calendar_provider import (
    clone_state,
    create_calendar,
    create_event,
    delete_calendar,
    delete_event,
    get_calendar,
    get_event,
    load_calendar_state,
    save_calendar_state,
    store_proposal,
    update_event,
)
from app.services.calendar_conflicts import detect_conflicts
from app.services.calendar_read import current_timestamp, parse_datetime, schedule_snapshot_hash


def validate_event_payload(
    payload: dict[str, Any],
    *,
    require_full: bool = False,
) -> dict[str, Any]:
    if require_full:
        for field_name in ("title", "start", "end"):
            if not payload.get(field_name):
                raise AppError(
                    code="invalid_event_payload",
                    message=f"Field '{field_name}' is required for this event operation.",
                    status_code=422,
                )
    elif not payload:
        raise AppError(
            code="invalid_event_payload",
            message="At least one event field must be supplied for this operation.",
            status_code=422,
        )

    if payload.get("start"):
        parse_datetime(payload["start"])
    if payload.get("end"):
        parse_datetime(payload["end"])
    if payload.get("start") and payload.get("end"):
        if parse_datetime(payload["end"]) <= parse_datetime(payload["start"]):
            raise AppError(
                code="invalid_time_range",
                message="Event end must be after event start.",
                status_code=422,
            )
    return payload


def build_warnings(
    operation_type: str,
    before_state: dict[str, Any] | None,
    after_state: dict[str, Any] | None,
    preview_state: dict[str, Any],
    calendar_id: str | None,
) -> list[str]:
    warnings: list[str] = []
    if operation_type in {"delete_event", "delete_calendar"}:
        warnings.append("This operation is destructive and requires explicit confirmation.")

    if calendar_id and after_state and after_state.get("events"):
        calendar_events = [
            event for event in preview_state["events"] if event["calendar_id"] == calendar_id
        ]
        conflicts = detect_conflicts(calendar_events)
        if conflicts:
            warnings.append(f"Preview contains {len(conflicts)} timing conflict warning(s).")

    if operation_type == "delete_calendar" and before_state:
        event_count = len(before_state.get("events", []))
        if event_count:
            warnings.append(f"Deleting this calendar also removes {event_count} event(s).")

    return warnings


def target_summary(request_payload: dict[str, Any]) -> str:
    operation_type = request_payload["operation_type"]
    calendar_id = request_payload.get("calendar_id") or "primary"
    event_id = request_payload.get("event_id")
    event_payload = request_payload.get("event") or {}
    calendar_payload = request_payload.get("calendar") or {}

    if operation_type == "create_event":
        return f"Create event '{event_payload.get('title', 'untitled')}' in calendar '{calendar_id}'."
    if operation_type in {"update_event", "move_event"}:
        return f"Update event '{event_id}' in calendar '{calendar_id}'."
    if operation_type == "delete_event":
        return f"Delete event '{event_id}' from calendar '{calendar_id}'."
    if operation_type == "create_calendar":
        return f"Create calendar '{calendar_payload.get('name', 'untitled')}'."
    return f"Delete calendar '{calendar_id}'."


def preview_operation(
    state: dict[str, Any],
    request_payload: dict[str, Any],
) -> tuple[dict[str, Any] | None, dict[str, Any] | None, dict[str, Any]]:
    operation_type = request_payload["operation_type"]
    calendar_id = request_payload.get("calendar_id") or "primary"
    event_id = request_payload.get("event_id")
    recurring_scope = request_payload.get("recurring_scope")
    event_payload = request_payload.get("event") or {}
    calendar_payload = request_payload.get("calendar") or {}

    preview_state = clone_state(state)

    if operation_type == "create_event":
        created_events = create_event(
            preview_state,
            calendar_id,
            validate_event_payload(event_payload, require_full=True),
        )
        return None, {"events": created_events}, preview_state

    if operation_type in {"update_event", "move_event"}:
        before_event = get_event(preview_state, calendar_id, event_id)
        updated_events = update_event(
            preview_state,
            calendar_id,
            event_id,
            validate_event_payload(event_payload),
            recurring_scope,
        )
        return {"events": [before_event]}, {"events": updated_events}, preview_state

    if operation_type == "delete_event":
        before_event = get_event(preview_state, calendar_id, event_id)
        deleted_events = delete_event(preview_state, calendar_id, event_id, recurring_scope)
        return {"events": [before_event]}, {"events": deleted_events}, preview_state

    if operation_type == "create_calendar":
        created_calendar = create_calendar(preview_state, calendar_payload)
        return None, {"calendar": created_calendar}, preview_state

    before_calendar = get_calendar(preview_state, calendar_id)
    before_events = [
        event for event in preview_state["events"] if event["calendar_id"] == calendar_id
    ]
    deleted_calendar = delete_calendar(preview_state, calendar_id)
    return {"calendar": before_calendar, "events": before_events}, {"calendar": deleted_calendar}, preview_state


def apply_operation(
    state: dict[str, Any],
    request_payload: dict[str, Any],
) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    operation_type = request_payload["operation_type"]
    calendar_id = request_payload.get("calendar_id") or "primary"
    event_id = request_payload.get("event_id")
    recurring_scope = request_payload.get("recurring_scope")
    event_payload = request_payload.get("event") or {}
    calendar_payload = request_payload.get("calendar") or {}

    if operation_type == "create_event":
        created_events = create_event(
            state,
            calendar_id,
            validate_event_payload(event_payload, require_full=True),
        )
        return None, {"events": created_events}

    if operation_type in {"update_event", "move_event"}:
        before_events = [get_event(state, calendar_id, event_id)]
        updated_events = update_event(
            state,
            calendar_id,
            event_id,
            validate_event_payload(event_payload),
            recurring_scope,
        )
        return {"events": before_events}, {"events": updated_events}

    if operation_type == "delete_event":
        before_events = [get_event(state, calendar_id, event_id)]
        deleted_events = delete_event(state, calendar_id, event_id, recurring_scope)
        return {"events": before_events}, {"events": deleted_events}

    if operation_type == "create_calendar":
        created_calendar = create_calendar(state, calendar_payload)
        return None, {"calendar": created_calendar}

    before_calendar = get_calendar(state, calendar_id)
    before_events = [event for event in state["events"] if event["calendar_id"] == calendar_id]
    deleted_calendar = delete_calendar(state, calendar_id)
    return {"calendar": before_calendar, "events": before_events}, {"calendar": deleted_calendar}


def create_calendar_operation_proposal(request_payload: dict[str, Any]) -> dict[str, Any]:
    state = load_calendar_state()
    before_state, after_state, preview_state = preview_operation(state, request_payload)
    proposal = {
        "proposal_id": f"prop-{uuid.uuid4().hex[:12]}",
        "operation_type": request_payload["operation_type"],
        "status": "proposed",
        "actor": request_payload.get("actor", "agent"),
        "target_summary": target_summary(request_payload),
        "calendar_id": request_payload.get("calendar_id"),
        "event_id": request_payload.get("event_id"),
        "recurring_scope": request_payload.get("recurring_scope"),
        "requires_confirmation": True,
        "warnings": build_warnings(
            request_payload["operation_type"],
            before_state,
            after_state,
            preview_state,
            request_payload.get("calendar_id"),
        ),
        "before_state": before_state,
        "after_state": after_state,
        "snapshot_hash": schedule_snapshot_hash(state),
        "created_at": current_timestamp(),
        "executed_at": None,
        "error_message": None,
        "request_payload": request_payload,
    }
    store_proposal(state, proposal)
    save_calendar_state(state)
    return {key: value for key, value in proposal.items() if key != "request_payload"}
