from __future__ import annotations

from typing import Any

from fastapi.testclient import TestClient


CALENDAR_DATE = "2026-04-18"
BRIEFING_REQUEST = {
    "user_input": "오늘 일정 브리핑해줘",
    "location": "Seoul",
    "date": CALENDAR_DATE,
    "user_name": "Jarvis User",
}


def _create_event_proposal(
    client: TestClient,
    *,
    title: str,
    start: str,
    end: str,
    location: str,
    priority: str,
    actor: str = "agent",
) -> dict[str, Any]:
    response = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "create_event",
            "calendar_id": "primary",
            "actor": actor,
            "event": {
                "title": title,
                "start": start,
                "end": end,
                "location": location,
                "priority": priority,
            },
        },
    )

    assert response.status_code == 201
    return response.json()


def _execute_proposal(client: TestClient, proposal: dict[str, Any]):
    return client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": proposal["proposal_id"],
            "snapshot_hash": proposal["snapshot_hash"],
            "confirmed": True,
        },
    )


def _get_events_for_default_day(client: TestClient) -> list[dict[str, Any]]:
    response = client.get("/api/v1/calendars/primary/events", params={"date": CALENDAR_DATE})

    assert response.status_code == 200
    return response.json()["events"]


def _get_briefing_calendar(client: TestClient) -> dict[str, Any]:
    response = client.post("/api/v1/briefings", json=BRIEFING_REQUEST)

    assert response.status_code == 200
    return response.json()["calendar"]


def test_execute_lifecycle_updates_events_and_audit_log(client: TestClient) -> None:
    proposal = _create_event_proposal(
        client,
        title="Integration Lifecycle Review",
        start="2026-04-18T13:00:00+09:00",
        end="2026-04-18T13:45:00+09:00",
        location="Office",
        priority="high",
        actor="worker-e",
    )

    execute_response = _execute_proposal(client, proposal)

    assert execute_response.status_code == 200
    execute_body = execute_response.json()
    assert execute_body["status"] == "executed"

    events = _get_events_for_default_day(client)
    created_event = next(event for event in events if event["title"] == "Integration Lifecycle Review")
    assert created_event["start"] == "2026-04-18T13:00:00+09:00"
    assert created_event["end"] == "2026-04-18T13:45:00+09:00"
    assert created_event["location"] == "Office"
    assert created_event["priority"] == "high"

    audit_response = client.get("/api/v1/calendar-operation-audit")

    assert audit_response.status_code == 200
    audit_record = next(
        record
        for record in audit_response.json()["records"]
        if record["proposal_id"] == proposal["proposal_id"]
    )
    assert audit_record["result_status"] == "executed"
    assert audit_record["actor"] == "worker-e"
    assert audit_record["recorded_at"] == execute_body["executed_at"]
    assert audit_record["after_state"]["events"][0]["title"] == "Integration Lifecycle Review"


def test_executing_older_proposal_after_newer_execution_returns_stale_conflict(
    client: TestClient,
) -> None:
    proposal_a = _create_event_proposal(
        client,
        title="Stale Proposal A",
        start="2026-04-18T18:00:00+09:00",
        end="2026-04-18T18:30:00+09:00",
        location="Room A",
        priority="medium",
    )
    proposal_b = _create_event_proposal(
        client,
        title="Stale Proposal B",
        start="2026-04-18T19:00:00+09:00",
        end="2026-04-18T19:30:00+09:00",
        location="Room B",
        priority="medium",
    )

    execute_b = _execute_proposal(client, proposal_b)

    assert execute_b.status_code == 200

    execute_a = _execute_proposal(client, proposal_a)

    assert execute_a.status_code == 409
    body = execute_a.json()
    assert body["error"]["code"] == "proposal_stale"
    assert body["error"]["message"] == "Calendar state changed after this proposal was created."


def test_briefing_endpoint_reflects_executed_calendar_changes(client: TestClient) -> None:
    briefing_before = _get_briefing_calendar(client)

    proposal = _create_event_proposal(
        client,
        title="Briefing Delta Event",
        start="2026-04-18T14:00:00+09:00",
        end="2026-04-18T14:30:00+09:00",
        location="HQ",
        priority="high",
    )

    execute_response = _execute_proposal(client, proposal)

    assert execute_response.status_code == 200

    briefing_after = _get_briefing_calendar(client)
    after_titles = {event["title"] for event in briefing_after["events"]}

    assert "Briefing Delta Event" not in {event["title"] for event in briefing_before["events"]}
    assert "Briefing Delta Event" in after_titles
    assert len(briefing_after["events"]) == len(briefing_before["events"]) + 1
    assert briefing_after["summary"] != briefing_before["summary"]
    assert f"{len(briefing_after['events'])} scheduled event(s)" in briefing_after["summary"]


def test_proposal_detail_endpoint_shows_preview_before_execution_and_status_after_execution(
    client: TestClient,
) -> None:
    proposal = _create_event_proposal(
        client,
        title="Proposal Detail Event",
        start="2026-04-18T20:00:00+09:00",
        end="2026-04-18T20:45:00+09:00",
        location="War Room",
        priority="low",
    )

    detail_before_response = client.get(f"/api/v1/calendar-operations/{proposal['proposal_id']}")

    assert detail_before_response.status_code == 200
    detail_before = detail_before_response.json()
    preview_event = detail_before["after_state"]["events"][0]
    assert detail_before["status"] == "proposed"
    assert detail_before["executed_at"] is None
    assert detail_before["calendar_id"] == "primary"
    assert detail_before["target_summary"] == "Create event 'Proposal Detail Event' in calendar 'primary'."
    assert preview_event["title"] == "Proposal Detail Event"
    assert preview_event["start"] == "2026-04-18T20:00:00+09:00"
    assert preview_event["end"] == "2026-04-18T20:45:00+09:00"
    assert preview_event["location"] == "War Room"
    assert preview_event["priority"] == "low"

    execute_response = _execute_proposal(client, proposal)

    assert execute_response.status_code == 200
    execute_body = execute_response.json()

    detail_after_response = client.get(f"/api/v1/calendar-operations/{proposal['proposal_id']}")

    assert detail_after_response.status_code == 200
    detail_after = detail_after_response.json()
    executed_event = detail_after["after_state"]["events"][0]
    assert detail_after["status"] == "executed"
    assert detail_after["executed_at"] == execute_body["executed_at"]
    assert detail_after["snapshot_hash"] == proposal["snapshot_hash"]
    assert detail_after["error_message"] is None
    assert executed_event["title"] == "Proposal Detail Event"
    assert executed_event["start"] == "2026-04-18T20:00:00+09:00"
    assert executed_event["end"] == "2026-04-18T20:45:00+09:00"
    assert executed_event["location"] == "War Room"
    assert executed_event["priority"] == "low"
