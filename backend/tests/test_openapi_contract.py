from __future__ import annotations


def _openapi_schema(client) -> dict:
    response = client.get("/openapi.json")

    assert response.status_code == 200
    return response.json()


def test_openapi_lists_calendar_paths_and_base_metadata(client) -> None:
    schema = _openapi_schema(client)

    assert schema["info"]["title"] == "Jarvis Multi-Agent API"
    assert schema["info"]["version"] == "0.2.0"

    calendar_paths = {path for path in schema["paths"] if "calendar" in path}
    assert calendar_paths == {
        "/api/v1/calendars",
        "/api/v1/calendars/{calendar_id}",
        "/api/v1/calendars/{calendar_id}/events",
        "/api/v1/calendars/{calendar_id}/conflicts",
        "/api/v1/calendars/{calendar_id}/summary",
        "/api/v1/calendar-operations/proposals",
        "/api/v1/calendar-operations",
        "/api/v1/calendar-operations/{proposal_id}",
        "/api/v1/calendar-operations/{proposal_id}/execute",
        "/api/v1/calendar-operation-audit",
    }


def test_openapi_calendar_read_routes_reference_expected_parameters_and_schemas(client) -> None:
    schema = _openapi_schema(client)
    paths = schema["paths"]
    components = schema["components"]["schemas"]

    events_get = paths["/api/v1/calendars/{calendar_id}/events"]["get"]
    conflicts_get = paths["/api/v1/calendars/{calendar_id}/conflicts"]["get"]
    summary_get = paths["/api/v1/calendars/{calendar_id}/summary"]["get"]

    for operation, response_ref in (
        (events_get, "#/components/schemas/CalendarEventsResponse"),
        (conflicts_get, "#/components/schemas/CalendarConflictsResponse"),
        (summary_get, "#/components/schemas/CalendarSummaryResponse"),
    ):
        assert operation["tags"] == ["calendars"]
        assert [parameter["name"] for parameter in operation["parameters"]] == [
            "calendar_id",
            "date",
            "start_date",
            "end_date",
        ]
        assert operation["parameters"][0]["schema"]["minLength"] == 1
        assert operation["responses"]["200"]["content"]["application/json"]["schema"]["$ref"] == response_ref
        assert operation["responses"]["404"]["content"]["application/json"]["schema"]["$ref"] == (
            "#/components/schemas/ErrorResponse"
        )
        assert operation["responses"]["422"]["content"]["application/json"]["schema"]["$ref"] == (
            "#/components/schemas/ErrorResponse"
        )
        assert set(operation["responses"]["422"]["content"]["application/json"]["examples"]) == {
            "invalid_query",
            "invalid_date",
            "validation_error",
        }

    assert set(components["CalendarEventsResponse"]["properties"]) == {
        "owner",
        "feature",
        "uses_mock",
        "calendar",
        "events",
    }
    assert "range_label" not in components["CalendarEventsResponse"]["properties"]

    assert set(components["CalendarSummaryResponse"]["required"]) == {
        "owner",
        "feature",
        "calendar",
        "date",
        "summary",
        "events",
        "conflicts",
    }


def test_openapi_calendar_operation_contract_exposes_request_models_and_enums(client) -> None:
    schema = _openapi_schema(client)
    paths = schema["paths"]
    components = schema["components"]["schemas"]

    proposal_post = paths["/api/v1/calendar-operations/proposals"]["post"]
    execute_post = paths["/api/v1/calendar-operations/{proposal_id}/execute"]["post"]

    assert proposal_post["tags"] == ["calendar-operations"]
    assert proposal_post["requestBody"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/CalendarOperationProposalRequest"
    )
    assert proposal_post["responses"]["201"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/CalendarOperationProposal"
    )
    assert proposal_post["responses"]["404"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/ErrorResponse"
    )
    assert set(proposal_post["responses"]["404"]["content"]["application/json"]["examples"]) == {
        "calendar_not_found",
        "event_not_found",
    }
    assert proposal_post["responses"]["409"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/ErrorResponse"
    )
    assert set(proposal_post["responses"]["409"]["content"]["application/json"]["examples"]) == {
        "primary_calendar_protected",
    }
    assert proposal_post["responses"]["422"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/ErrorResponse"
    )
    assert set(proposal_post["responses"]["422"]["content"]["application/json"]["examples"]) == {
        "validation_error",
        "invalid_event_payload",
        "invalid_datetime",
        "invalid_time_range",
        "recurring_scope_required",
    }

    assert execute_post["tags"] == ["calendar-operations"]
    assert [parameter["name"] for parameter in execute_post["parameters"]] == ["proposal_id"]
    assert execute_post["requestBody"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/CalendarOperationExecuteRequest"
    )
    assert execute_post["responses"]["200"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/CalendarOperationResult"
    )
    assert execute_post["responses"]["404"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/ErrorResponse"
    )
    assert execute_post["responses"]["409"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/ErrorResponse"
    )
    assert execute_post["responses"]["422"]["content"]["application/json"]["schema"]["$ref"] == (
        "#/components/schemas/ErrorResponse"
    )

    proposal_request = components["CalendarOperationProposalRequest"]
    assert proposal_request["required"] == ["operation_type"]
    assert proposal_request["properties"]["actor"]["default"] == "agent"
    assert proposal_request["properties"]["calendar_id"]["default"] == "primary"
    assert proposal_request["properties"]["event"]["anyOf"][0]["$ref"] == "#/components/schemas/CalendarEventMutation"
    assert proposal_request["properties"]["calendar"]["anyOf"][0]["$ref"] == "#/components/schemas/CalendarMutation"

    execute_request = components["CalendarOperationExecuteRequest"]
    assert set(execute_request["required"]) == {"proposal_id", "snapshot_hash"}
    assert execute_request["properties"]["confirmed"]["default"] is True

    assert components["CalendarOperationType"]["enum"] == [
        "create_event",
        "update_event",
        "move_event",
        "delete_event",
        "create_calendar",
        "delete_calendar",
    ]
    assert components["RecurringEditScope"]["enum"] == [
        "occurrence",
        "following",
        "series",
    ]
    assert components["CalendarOperationStatus"]["enum"] == [
        "proposed",
        "executed",
        "rejected",
        "stale",
        "failed",
    ]

    assert components["CalendarEventMutation"]["properties"]["all_day"]["default"] is False
    assert components["CalendarEventMutation"]["properties"]["recurring"]["default"] is False
    assert components["CalendarMutation"]["required"] == ["name"]
    assert components["CalendarMutation"]["properties"]["timezone"]["default"] == "Asia/Seoul"
