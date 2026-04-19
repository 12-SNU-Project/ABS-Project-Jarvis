from __future__ import annotations

import json
from pathlib import Path


def test_health_route_uses_versioned_path(client) -> None:
    response = client.get("/api/v1/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert "model" in body


def test_briefings_route_still_contains_calendar_section(client) -> None:
    response = client.post(
        "/api/v1/briefings",
        json={
            "user_input": "오늘 일정 브리핑해줘",
            "location": "Seoul",
            "date": "2026-04-18",
            "user_name": "Jarvis User",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["calendar"]["calendar_id"] == "primary"
    assert isinstance(body["calendar"]["events"], list)


def test_list_calendars_returns_primary_calendar(client) -> None:
    response = client.get("/api/v1/calendars")

    assert response.status_code == 200
    body = response.json()
    assert body["feature"] == "calendar"
    assert body["calendars"][0]["id"] == "primary"


def test_get_calendar_events_filters_by_date(client) -> None:
    response = client.get("/api/v1/calendars/primary/events", params={"date": "2026-04-18"})

    assert response.status_code == 200
    body = response.json()
    assert body["calendar"]["id"] == "primary"
    assert len(body["events"]) >= 3


def test_get_calendar_events_normalizes_legacy_null_priority(client) -> None:
    from app.core.config import get_settings
    from app.providers.calendar_provider import load_calendar_state

    state = load_calendar_state()
    state["events"][0]["priority"] = None
    Path(get_settings().calendar_state_path).write_text(json.dumps(state), encoding="utf-8")

    response = client.get("/api/v1/calendars/primary/events", params={"date": "2026-04-18"})

    assert response.status_code == 200
    body = response.json()
    repaired_event = next(event for event in body["events"] if event["id"] == state["events"][0]["id"])
    assert all(event["priority"] for event in body["events"])
    assert repaired_event["priority"] == "medium"


def test_get_calendar_events_rejects_mixed_date_queries(client) -> None:
    response = client.get(
        "/api/v1/calendars/primary/events",
        params={"date": "2026-04-18", "start_date": "2026-04-18", "end_date": "2026-04-19"},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_query"


def test_create_event_requires_proposal_then_execute(client) -> None:
    proposal_response = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "create_event",
            "calendar_id": "primary",
            "actor": "agent",
            "event": {
                "title": "Customer Review",
                "start": "2026-04-18T13:00:00+09:00",
                "end": "2026-04-18T14:00:00+09:00",
                "location": "Office",
                "priority": "high",
            },
        },
    )

    assert proposal_response.status_code == 201
    proposal = proposal_response.json()
    assert proposal["status"] == "proposed"
    assert proposal["requires_confirmation"] is True

    execute_response = client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": proposal["proposal_id"],
            "snapshot_hash": proposal["snapshot_hash"],
            "confirmed": True,
        },
    )

    assert execute_response.status_code == 200
    result = execute_response.json()
    assert result["status"] == "executed"

    events_response = client.get("/api/v1/calendars/primary/events", params={"date": "2026-04-18"})
    titles = [event["title"] for event in events_response.json()["events"]]
    assert "Customer Review" in titles


def test_create_event_without_priority_defaults_to_medium(client) -> None:
    proposal_response = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "create_event",
            "calendar_id": "primary",
            "actor": "agent",
            "event": {
                "title": "Default Priority Event",
                "start": "2026-04-18T15:00:00+09:00",
                "end": "2026-04-18T16:00:00+09:00",
            },
        },
    )

    assert proposal_response.status_code == 201
    proposal = proposal_response.json()

    execute_response = client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": proposal["proposal_id"],
            "snapshot_hash": proposal["snapshot_hash"],
            "confirmed": True,
        },
    )

    assert execute_response.status_code == 200

    events_response = client.get("/api/v1/calendars/primary/events", params={"date": "2026-04-18"})
    created_event = next(event for event in events_response.json()["events"] if event["title"] == "Default Priority Event")
    assert created_event["priority"] == "medium"


def test_recurring_operation_requires_explicit_scope(client) -> None:
    response = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "delete_event",
            "calendar_id": "primary",
            "event_id": "evt-series-1",
            "actor": "agent",
        },
    )

    assert response.status_code == 422
    body = response.json()
    assert body["error"]["code"] == "recurring_scope_required"


def test_recurring_operation_with_scope_is_allowed(client) -> None:
    proposal_response = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "update_event",
            "calendar_id": "primary",
            "event_id": "evt-series-1",
            "recurring_scope": "occurrence",
            "actor": "agent",
            "event": {
                "title": "Team Sync Renamed",
            },
        },
    )

    assert proposal_response.status_code == 201
    proposal = proposal_response.json()

    execute_response = client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": proposal["proposal_id"],
            "snapshot_hash": proposal["snapshot_hash"],
            "confirmed": True,
        },
    )

    assert execute_response.status_code == 200
    events_response = client.get("/api/v1/calendars/primary/events", params={"start_date": "2026-04-18", "end_date": "2026-05-05"})
    recurring_events = [event for event in events_response.json()["events"] if event["id"].startswith("evt-series")]
    titles = [event["title"] for event in recurring_events]
    assert "Team Sync Renamed" in titles
    assert "Team Sync" in titles
    renamed_event = next(event for event in recurring_events if event["title"] == "Team Sync Renamed")
    assert renamed_event["recurring"] is True


def test_execute_rejects_stale_proposal(client) -> None:
    proposal_a = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "create_event",
            "calendar_id": "primary",
            "event": {
                "title": "Proposal A",
                "start": "2026-04-18T18:00:00+09:00",
                "end": "2026-04-18T19:00:00+09:00",
            },
        },
    ).json()
    proposal_b = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "create_event",
            "calendar_id": "primary",
            "event": {
                "title": "Proposal B",
                "start": "2026-04-18T20:00:00+09:00",
                "end": "2026-04-18T21:00:00+09:00",
            },
        },
    ).json()

    execute_b = client.post(
        f"/api/v1/calendar-operations/{proposal_b['proposal_id']}/execute",
        json={
            "proposal_id": proposal_b["proposal_id"],
            "snapshot_hash": proposal_b["snapshot_hash"],
            "confirmed": True,
        },
    )
    assert execute_b.status_code == 200

    execute_a = client.post(
        f"/api/v1/calendar-operations/{proposal_a['proposal_id']}/execute",
        json={
            "proposal_id": proposal_a["proposal_id"],
            "snapshot_hash": proposal_a["snapshot_hash"],
            "confirmed": True,
        },
    )

    assert execute_a.status_code == 409
    assert execute_a.json()["error"]["code"] == "proposal_stale"


def test_execute_rejects_mismatched_proposal_identifier(client) -> None:
    proposal = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "create_event",
            "calendar_id": "primary",
            "event": {
                "title": "Mismatch Test",
                "start": "2026-04-18T09:00:00+09:00",
                "end": "2026-04-18T09:30:00+09:00",
            },
        },
    ).json()

    response = client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": "prop-other",
            "snapshot_hash": proposal["snapshot_hash"],
            "confirmed": True,
        },
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "proposal_mismatch"


def test_audit_route_returns_executed_operation_records(client) -> None:
    proposal = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "create_event",
            "calendar_id": "primary",
            "actor": "agent",
            "event": {
                "title": "Audit Trail Review",
                "start": "2026-04-18T14:30:00+09:00",
                "end": "2026-04-18T15:00:00+09:00",
            },
        },
    ).json()

    client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": proposal["proposal_id"],
            "snapshot_hash": proposal["snapshot_hash"],
            "confirmed": True,
        },
    )

    audit_response = client.get("/api/v1/calendar-operation-audit")

    assert audit_response.status_code == 200
    body = audit_response.json()
    assert len(body["records"]) >= 1
    assert body["records"][0]["proposal_id"] == proposal["proposal_id"]
