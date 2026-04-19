from __future__ import annotations

from copy import deepcopy
from datetime import datetime, timedelta


def _load_state() -> dict:
    from app.providers.calendar_provider import load_calendar_state

    return load_calendar_state()


def _event_by_id(state: dict, event_id: str) -> dict:
    return next(event for event in state["events"] if event["id"] == event_id)


def _audit_record_by_proposal_id(state: dict, proposal_id: str) -> dict:
    return next(record for record in state["audit_records"] if record["proposal_id"] == proposal_id)


def _propose_operation(client, payload: dict) -> dict:
    response = client.post("/api/v1/calendar-operations/proposals", json=payload)
    assert response.status_code == 201, response.json()
    return response.json()


def _execute_operation(client, proposal: dict, *, snapshot_hash: str | None = None):
    return client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": proposal["proposal_id"],
            "snapshot_hash": snapshot_hash or proposal["snapshot_hash"],
            "confirmed": True,
        },
    )


def _reject_operation(client, proposal: dict, *, reason: str | None = None):
    payload = {"proposal_id": proposal["proposal_id"]}
    if reason is not None:
        payload["reason"] = reason
    return client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/reject",
        json=payload,
    )


def test_single_event_move_preserves_duration(client) -> None:
    before_state = _load_state()
    original_event = _event_by_id(before_state, "evt-1")
    original_start = datetime.fromisoformat(original_event["start"])
    original_end = datetime.fromisoformat(original_event["end"])
    original_duration = original_end - original_start
    moved_start = (original_start + timedelta(hours=2)).isoformat()

    proposal = _propose_operation(
        client,
        {
            "operation_type": "move_event",
            "calendar_id": "primary",
            "event_id": "evt-1",
            "actor": "agent",
            "event": {
                "start": moved_start,
            },
        },
    )

    response = _execute_operation(client, proposal)

    assert response.status_code == 200
    moved_event = _event_by_id(_load_state(), "evt-1")
    assert moved_event["start"] == moved_start
    assert (
        datetime.fromisoformat(moved_event["end"])
        - datetime.fromisoformat(moved_event["start"])
        == original_duration
    )


def test_recurring_move_occurrence_only_moves_one_occurrence(client) -> None:
    before_state = _load_state()
    before_events = {
        event_id: deepcopy(_event_by_id(before_state, event_id))
        for event_id in ("evt-series-1", "evt-series-2", "evt-series-3")
    }
    occurrence_start = (
        datetime.fromisoformat(before_events["evt-series-1"]["start"])
        + timedelta(hours=1, minutes=30)
    ).isoformat()

    proposal = _propose_operation(
        client,
        {
            "operation_type": "move_event",
            "calendar_id": "primary",
            "event_id": "evt-series-1",
            "recurring_scope": "occurrence",
            "actor": "agent",
            "event": {
                "start": occurrence_start,
            },
        },
    )

    response = _execute_operation(client, proposal)

    assert response.status_code == 200
    after_state = _load_state()
    moved_occurrence = _event_by_id(after_state, "evt-series-1")
    assert moved_occurrence["start"] == occurrence_start
    assert _event_by_id(after_state, "evt-series-2") == before_events["evt-series-2"]
    assert _event_by_id(after_state, "evt-series-3") == before_events["evt-series-3"]


def test_recurring_move_following_shifts_later_occurrences_by_delta(client) -> None:
    before_state = _load_state()
    before_events = {
        event_id: deepcopy(_event_by_id(before_state, event_id))
        for event_id in ("evt-series-1", "evt-series-2", "evt-series-3")
    }
    delta = timedelta(hours=2, minutes=15)
    shifted_start = (
        datetime.fromisoformat(before_events["evt-series-2"]["start"]) + delta
    ).isoformat()

    proposal = _propose_operation(
        client,
        {
            "operation_type": "move_event",
            "calendar_id": "primary",
            "event_id": "evt-series-2",
            "recurring_scope": "following",
            "actor": "agent",
            "event": {
                "start": shifted_start,
            },
        },
    )

    response = _execute_operation(client, proposal)

    assert response.status_code == 200
    after_state = _load_state()
    assert _event_by_id(after_state, "evt-series-1") == before_events["evt-series-1"]

    for event_id in ("evt-series-2", "evt-series-3"):
        before_event = before_events[event_id]
        after_event = _event_by_id(after_state, event_id)
        assert (
            datetime.fromisoformat(after_event["start"])
            - datetime.fromisoformat(before_event["start"])
            == delta
        )
        assert (
            datetime.fromisoformat(after_event["end"])
            - datetime.fromisoformat(before_event["end"])
            == delta
        )

    assert _event_by_id(after_state, "evt-series-2")["start"] == shifted_start
    assert _event_by_id(after_state, "evt-series-2")["start"] != _event_by_id(
        after_state,
        "evt-series-3",
    )["start"]


def test_recurring_move_following_proposal_before_state_contains_all_affected_events(client) -> None:
    before_state = _load_state()
    before_events = {
        event_id: deepcopy(_event_by_id(before_state, event_id))
        for event_id in ("evt-series-2", "evt-series-3")
    }
    shifted_start = (
        datetime.fromisoformat(before_events["evt-series-2"]["start"]) + timedelta(minutes=45)
    ).isoformat()

    proposal = _propose_operation(
        client,
        {
            "operation_type": "move_event",
            "calendar_id": "primary",
            "event_id": "evt-series-2",
            "recurring_scope": "following",
            "actor": "agent",
            "event": {
                "start": shifted_start,
            },
        },
    )

    before_ids = [event["id"] for event in proposal["before_state"]["events"]]
    after_ids = [event["id"] for event in proposal["after_state"]["events"]]

    assert before_ids == ["evt-series-2", "evt-series-3"]
    assert after_ids == ["evt-series-2", "evt-series-3"]
    for event_id, before_event in before_events.items():
        assert _event_by_id({"events": proposal["before_state"]["events"]}, event_id) == before_event


def test_recurring_move_execute_audit_before_state_contains_all_affected_events(client) -> None:
    scopes_to_expected_ids = {
        "following": ("evt-series-2", "evt-series-3"),
        "series": ("evt-series-1", "evt-series-2", "evt-series-3"),
    }

    for scope, expected_ids in scopes_to_expected_ids.items():
        before_state = _load_state()
        before_events = {
            event_id: deepcopy(_event_by_id(before_state, event_id)) for event_id in expected_ids
        }
        shifted_start = (
            datetime.fromisoformat(before_events["evt-series-2"]["start"]) + timedelta(minutes=30)
        ).isoformat()

        proposal = _propose_operation(
            client,
            {
                "operation_type": "move_event",
                "calendar_id": "primary",
                "event_id": "evt-series-2",
                "recurring_scope": scope,
                "actor": "agent",
                "event": {
                    "start": shifted_start,
                },
            },
        )

        response = _execute_operation(client, proposal)

        assert response.status_code == 200
        audit_record = _audit_record_by_proposal_id(_load_state(), proposal["proposal_id"])
        before_ids = [event["id"] for event in audit_record["before_state"]["events"]]
        after_ids = [event["id"] for event in audit_record["after_state"]["events"]]
        assert before_ids == list(expected_ids)
        assert after_ids == list(expected_ids)
        for event_id, before_event in before_events.items():
            assert _event_by_id({"events": audit_record["before_state"]["events"]}, event_id) == before_event


def test_recurring_move_occurrence_proposal_before_state_contains_only_anchor_event(client) -> None:
    before_state = _load_state()
    anchor_before = deepcopy(_event_by_id(before_state, "evt-series-2"))
    shifted_start = (
        datetime.fromisoformat(anchor_before["start"]) + timedelta(minutes=20)
    ).isoformat()

    proposal = _propose_operation(
        client,
        {
            "operation_type": "move_event",
            "calendar_id": "primary",
            "event_id": "evt-series-2",
            "recurring_scope": "occurrence",
            "actor": "agent",
            "event": {
                "start": shifted_start,
            },
        },
    )

    assert [event["id"] for event in proposal["before_state"]["events"]] == ["evt-series-2"]
    assert proposal["before_state"]["events"][0] == anchor_before


def test_execute_retry_after_success_returns_success_without_duplicate_audit_entries(client) -> None:
    proposal = _propose_operation(
        client,
        {
            "operation_type": "create_event",
            "calendar_id": "primary",
            "actor": "agent",
            "event": {
                "title": "Retry Safe Event",
                "start": "2026-04-18T19:00:00+09:00",
                "end": "2026-04-18T19:30:00+09:00",
            },
        },
    )

    first_response = _execute_operation(client, proposal)

    assert first_response.status_code == 200
    state_after_first = deepcopy(_load_state())
    first_result = first_response.json()

    second_response = _execute_operation(client, proposal)

    assert second_response.status_code == 200
    assert second_response.json() == first_result
    assert len(_load_state()["audit_records"]) == len(state_after_first["audit_records"])
    assert _load_state() == state_after_first


def test_reject_marks_proposal_rejected_without_mutating_calendar_state(client) -> None:
    before_state = _load_state()
    before_event = deepcopy(_event_by_id(before_state, "evt-1"))
    proposal = _propose_operation(
        client,
        {
            "operation_type": "move_event",
            "calendar_id": "primary",
            "event_id": "evt-1",
            "actor": "agent",
            "event": {
                "start": (datetime.fromisoformat(before_event["start"]) + timedelta(minutes=30)).isoformat(),
            },
        },
    )

    response = _reject_operation(client, proposal, reason="User declined the reschedule.")

    assert response.status_code == 200
    assert response.json()["status"] == "rejected"

    state = _load_state()
    assert _event_by_id(state, "evt-1") == before_event
    rejected_proposal = next(
        item for item in state["proposals"] if item["proposal_id"] == proposal["proposal_id"]
    )
    assert rejected_proposal["status"] == "rejected"
    assert rejected_proposal["error_message"] == "User declined the reschedule."

    audit_record = _audit_record_by_proposal_id(state, proposal["proposal_id"])
    assert audit_record["result_status"] == "rejected"
    assert audit_record["error_message"] == "User declined the reschedule."


def test_reject_retry_after_success_returns_success_without_duplicate_audit_entries(client) -> None:
    proposal = _propose_operation(
        client,
        {
            "operation_type": "delete_event",
            "calendar_id": "primary",
            "event_id": "evt-1",
            "actor": "agent",
        },
    )

    first_response = _reject_operation(client, proposal)
    state_after_first = deepcopy(_load_state())
    first_result = first_response.json()

    second_response = _reject_operation(client, proposal)

    assert first_response.status_code == 200
    assert second_response.status_code == 200
    assert second_response.json() == first_result
    assert len(_load_state()["audit_records"]) == len(state_after_first["audit_records"])
    assert _load_state() == state_after_first


def test_rejecting_executed_proposal_returns_conflict(client) -> None:
    proposal = _propose_operation(
        client,
        {
            "operation_type": "delete_event",
            "calendar_id": "primary",
            "event_id": "evt-1",
            "actor": "agent",
        },
    )

    execute_response = _execute_operation(client, proposal)
    reject_response = _reject_operation(client, proposal)

    assert execute_response.status_code == 200
    assert reject_response.status_code == 409
    assert reject_response.json()["error"]["code"] == "proposal_not_executable"


def test_omitted_calendar_id_is_persisted_as_primary_in_proposal_response_and_storage(client) -> None:
    proposal = _propose_operation(
        client,
        {
            "operation_type": "create_event",
            "actor": "agent",
            "event": {
                "title": "Implicit Primary Event",
                "start": "2026-04-18T21:00:00+09:00",
                "end": "2026-04-18T21:30:00+09:00",
            },
        },
    )

    assert proposal["calendar_id"] == "primary"
    stored_proposal = next(
        item
        for item in _load_state()["proposals"]
        if item["proposal_id"] == proposal["proposal_id"]
    )
    assert stored_proposal["calendar_id"] == "primary"
    assert stored_proposal["request_payload"]["calendar_id"] == "primary"


def test_wrong_snapshot_hash_returns_snapshot_mismatch_without_mutating_state(client) -> None:
    proposal = _propose_operation(
        client,
        {
            "operation_type": "create_event",
            "calendar_id": "primary",
            "actor": "agent",
            "event": {
                "title": "Snapshot Guard",
                "start": "2026-04-18T22:00:00+09:00",
                "end": "2026-04-18T22:30:00+09:00",
            },
        },
    )
    state_before_retry = deepcopy(_load_state())

    response = _execute_operation(client, proposal, snapshot_hash="wrong-hash")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "snapshot_mismatch"
    assert _load_state() == state_before_retry
