from __future__ import annotations

import pytest


def _assert_error_envelope(
    response,
    *,
    status_code: int,
    code: str,
    message: str,
    details: list[dict[str, str | None]],
) -> None:
    assert response.status_code == status_code
    assert response.json() == {
        "error": {
            "code": code,
            "message": message,
            "details": details,
        }
    }


def _create_create_event_proposal(client) -> dict[str, str]:
    response = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "create_event",
            "calendar_id": "primary",
            "event": {
                "title": "Error Contract Proposal",
                "start": "2026-04-18T09:00:00+09:00",
                "end": "2026-04-18T09:30:00+09:00",
            },
        },
    )

    assert response.status_code == 201
    return response.json()


def test_calendar_not_found_returns_404_with_error_envelope(client) -> None:
    response = client.get("/api/v1/calendars/missing")

    _assert_error_envelope(
        response,
        status_code=404,
        code="calendar_not_found",
        message="Calendar 'missing' not found.",
        details=[],
    )


def test_invalid_mixed_date_query_returns_422_with_error_envelope(client) -> None:
    response = client.get(
        "/api/v1/calendars/primary/events",
        params={
            "date": "2026-04-18",
            "start_date": "2026-04-18",
            "end_date": "2026-04-19",
        },
    )

    _assert_error_envelope(
        response,
        status_code=422,
        code="invalid_query",
        message="Use either date or start_date/end_date, not both.",
        details=[],
    )


def test_proposal_execute_path_body_mismatch_returns_409_with_proposal_id_detail(client) -> None:
    proposal = _create_create_event_proposal(client)

    response = client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": "prop-other",
            "snapshot_hash": proposal["snapshot_hash"],
            "confirmed": True,
        },
    )

    _assert_error_envelope(
        response,
        status_code=409,
        code="proposal_mismatch",
        message="The proposal_id in the body must match the path parameter.",
        details=[
            {
                "field": "proposal_id",
                "message": "The proposal_id in the body must match the path parameter.",
                "code": "proposal_mismatch",
            }
        ],
    )


def test_execute_with_confirmed_false_returns_422_with_error_envelope(client) -> None:
    proposal = _create_create_event_proposal(client)

    response = client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": proposal["proposal_id"],
            "snapshot_hash": proposal["snapshot_hash"],
            "confirmed": False,
        },
    )

    _assert_error_envelope(
        response,
        status_code=422,
        code="confirmation_required",
        message="confirmed must be true to execute an operation.",
        details=[],
    )


def test_delete_primary_calendar_proposal_returns_runtime_status_and_error_envelope(client) -> None:
    response = client.post(
        "/api/v1/calendar-operations/proposals",
        json={
            "operation_type": "delete_calendar",
            "calendar_id": "primary",
        },
    )

    _assert_error_envelope(
        response,
        status_code=409,
        code="primary_calendar_protected",
        message="The primary calendar cannot be deleted in mock mode.",
        details=[],
    )


@pytest.mark.parametrize(
    ("path", "body", "expected_detail_field"),
    [
        (
            "/api/v1/calendar-operations/proposals",
            {
                "operation_type": "create_event",
                "calendar_id": "primary",
                "event": {
                    "title": "Extra Field Proposal",
                    "start": "2026-04-18T09:00:00+09:00",
                    "end": "2026-04-18T09:30:00+09:00",
                    "extra_field": "boom",
                },
            },
            "event.extra_field",
        ),
    ],
)
def test_malformed_request_body_with_extra_fields_returns_422_validation_error(
    client,
    path: str,
    body: dict[str, object],
    expected_detail_field: str,
) -> None:
    response = client.post(path, json=body)

    _assert_error_envelope(
        response,
        status_code=422,
        code="validation_error",
        message="Request validation failed.",
        details=[
            {
                "field": expected_detail_field,
                "message": "Extra inputs are not permitted",
                "code": "extra_forbidden",
            }
        ],
    )


def test_execute_request_body_with_extra_fields_returns_422_validation_error(client) -> None:
    proposal = _create_create_event_proposal(client)

    response = client.post(
        f"/api/v1/calendar-operations/{proposal['proposal_id']}/execute",
        json={
            "proposal_id": proposal["proposal_id"],
            "snapshot_hash": proposal["snapshot_hash"],
            "confirmed": True,
            "extra_field": "boom",
        },
    )

    _assert_error_envelope(
        response,
        status_code=422,
        code="validation_error",
        message="Request validation failed.",
        details=[
            {
                "field": "extra_field",
                "message": "Extra inputs are not permitted",
                "code": "extra_forbidden",
            }
        ],
    )
