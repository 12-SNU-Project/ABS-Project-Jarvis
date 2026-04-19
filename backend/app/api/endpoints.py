from __future__ import annotations

from typing import Annotated, Any

from fastapi import APIRouter, Path, Query, status

from app.core.config import get_settings
from app.core.errors import AppError, error_detail
from app.schemas.schemas import (
    AdminSummary,
    AgentInterpretRequest,
    AgentInterpretResponse,
    BriefingRequest,
    CalendarAuditResponse,
    CalendarConflictsResponse,
    CalendarDetailResponse,
    CalendarEventsResponse,
    CalendarListResponse,
    CalendarOperationExecuteRequest,
    CalendarOperationListResponse,
    CalendarOperationProposal,
    CalendarOperationProposalRequest,
    CalendarOperationRejectRequest,
    CalendarOperationResult,
    CalendarSummaryResponse,
    ErrorResponse,
    FinalBriefing,
    HealthResponse,
    PresentationDemo,
    SlackSummaryRequest,
    SlackSummaryResponse,
)
from app.services.admin import get_admin_summary
from app.services.agent_interpreter import interpret_agent_instruction
from app.services.calendar import (
    create_calendar_operation_proposal,
    execute_calendar_operation,
    get_calendar_audit_log,
    get_calendar_conflicts_response,
    get_calendar_detail_response,
    get_calendar_events_response,
    get_calendar_operation_proposal,
    get_calendar_summary_response,
    list_calendar_operation_proposals,
    list_calendars_response,
    reject_calendar_operation,
)
from app.services.orchestrator import create_briefing
from app.services.slack_summary import summarize_slack_channel
from app.services.presentation import get_presentation_demo
from app.services.samsung_health import get_samsung_health_summary
from app.schemas.schemas import SamsungHealthSummary


router = APIRouter(prefix="/api/v1")


def _error_example(
    summary: str, *, code: str, message: str, field: str | None = None
) -> dict[str, Any]:
    details = []
    if field is not None:
        details.append({"field": field, "message": message, "code": code})
    return {
        "summary": summary,
        "value": {
            "error": {
                "code": code,
                "message": message,
                "details": details,
            }
        },
    }


def _error_response(description: str, **examples: dict[str, Any]) -> dict[str, Any]:
    return {
        "model": ErrorResponse,
        "description": description,
        "content": {"application/json": {"examples": examples}},
    }


CALENDAR_NOT_FOUND_RESPONSE = _error_response(
    "The requested calendar does not exist.",
    calendar_not_found=_error_example(
        "Calendar not found",
        code="calendar_not_found",
        message="Calendar 'primary' not found.",
    ),
)
CALENDAR_QUERY_ERROR_RESPONSE = _error_response(
    "The calendar query parameters were invalid.",
    invalid_query=_error_example(
        "Mixed date filters",
        code="invalid_query",
        message="Use either date or start_date/end_date, not both.",
    ),
    invalid_date=_error_example(
        "Malformed date",
        code="invalid_date",
        message="Invalid date value '2026/04/18'.",
        field="date",
    ),
    validation_error=_error_example(
        "Schema validation failure",
        code="validation_error",
        message="Request validation failed.",
        field="start_date",
    ),
)
PROPOSAL_NOT_FOUND_RESPONSE = _error_response(
    "The requested proposal does not exist.",
    proposal_not_found=_error_example(
        "Proposal not found",
        code="proposal_not_found",
        message="Proposal 'prop-abc123def456' not found.",
    ),
)
PROPOSAL_CREATE_NOT_FOUND_RESPONSE = _error_response(
    "The referenced calendar or event does not exist.",
    calendar_not_found=_error_example(
        "Calendar not found",
        code="calendar_not_found",
        message="Calendar 'secondary' not found.",
    ),
    event_not_found=_error_example(
        "Event not found",
        code="event_not_found",
        message="Event 'evt-missing' not found in calendar 'primary'.",
    ),
)
PROPOSAL_CREATE_VALIDATION_RESPONSE = _error_response(
    "The proposal request payload was invalid.",
    validation_error=_error_example(
        "Request schema validation failure",
        code="validation_error",
        message="Request validation failed.",
        field="event.start",
    ),
    invalid_event_payload=_error_example(
        "Missing event payload",
        code="invalid_event_payload",
        message="Field 'title' is required for this event operation.",
        field="event.title",
    ),
    invalid_datetime=_error_example(
        "Malformed datetime",
        code="invalid_datetime",
        message="Invalid datetime value '2026/04/18 09:00'.",
        field="event.start",
    ),
    invalid_time_range=_error_example(
        "Invalid time range",
        code="invalid_time_range",
        message="Event end must be after event start.",
        field="event.end",
    ),
    recurring_scope_required=_error_example(
        "Recurring scope missing",
        code="recurring_scope_required",
        message="Recurring event operations require an explicit scope.",
        field="recurring_scope",
    ),
)
PROPOSAL_CREATE_CONFLICT_RESPONSE = _error_response(
    "The proposal could not be created because of a state conflict.",
    primary_calendar_protected=_error_example(
        "Primary calendar protected",
        code="primary_calendar_protected",
        message="The primary calendar cannot be deleted in mock mode.",
    ),
)
PROPOSAL_EXECUTE_VALIDATION_RESPONSE = _error_response(
    "The execute request payload was invalid.",
    validation_error=_error_example(
        "Request schema validation failure",
        code="validation_error",
        message="Request validation failed.",
        field="proposal_id",
    ),
    confirmation_required=_error_example(
        "Confirmation missing",
        code="confirmation_required",
        message="confirmed must be true to execute an operation.",
        field="confirmed",
    ),
)
PROPOSAL_REJECT_VALIDATION_RESPONSE = _error_response(
    "The reject request payload was invalid.",
    validation_error=_error_example(
        "Request schema validation failure",
        code="validation_error",
        message="Request validation failed.",
        field="proposal_id",
    ),
)
PROPOSAL_CONFLICT_RESPONSE = _error_response(
    "The proposal could not be executed because of a state conflict.",
    proposal_mismatch=_error_example(
        "Path/body mismatch",
        code="proposal_mismatch",
        message="The proposal_id in the body must match the path parameter.",
        field="proposal_id",
    ),
    snapshot_mismatch=_error_example(
        "Snapshot mismatch",
        code="snapshot_mismatch",
        message="The supplied snapshot hash does not match the proposal.",
        field="snapshot_hash",
    ),
    proposal_not_executable=_error_example(
        "Proposal already resolved",
        code="proposal_not_executable",
        message="Proposal 'prop-abc123def456' is already in status 'executed'.",
    ),
    proposal_stale=_error_example(
        "Proposal became stale",
        code="proposal_stale",
        message="Calendar state changed after this proposal was created.",
    ),
)
AGENT_INTERPRET_ERROR_RESPONSE = _error_response(
    "The natural-language instruction could not be interpreted.",
    openai_not_configured=_error_example(
        "OpenAI not configured",
        code="openai_not_configured",
        message="OPENAI_API_KEY is not configured for the backend agent interpreter.",
    ),
    openai_request_failed=_error_example(
        "OpenAI request failed",
        code="openai_request_failed",
        message="The OpenAI API rejected the request.",
    ),
    openai_invalid_response=_error_example(
        "OpenAI invalid response",
        code="openai_invalid_response",
        message="OpenAI returned invalid JSON for the command interpretation.",
    ),
)


CalendarId = Annotated[
    str,
    Path(min_length=1, description="Opaque calendar identifier.", examples=["primary"]),
]
ProposalId = Annotated[
    str,
    Path(
        min_length=1,
        description="Opaque proposal identifier.",
        examples=["prop-abc123def456"],
    ),
]
DateQuery = Annotated[
    str | None,
    Query(
        alias="date",
        description="Single calendar day in YYYY-MM-DD format. Cannot be combined with start_date or end_date.",
        examples=["2026-04-18"],
    ),
]
StartDateQuery = Annotated[
    str | None,
    Query(
        description="Inclusive range start in YYYY-MM-DD format. Must be paired with end_date.",
        examples=["2026-04-18"],
    ),
]
EndDateQuery = Annotated[
    str | None,
    Query(
        description="Inclusive range end in YYYY-MM-DD format. Must be paired with start_date.",
        examples=["2026-04-19"],
    ),
]


@router.get("/health", response_model=HealthResponse, tags=["system"])
def health_check() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        status="ok",
        use_mocks=settings.use_mocks,
        samsung_health_use_mock=settings.samsung_health_use_mock,
        model=settings.openai_model,
    )


@router.get("/health/sleep", response_model=SamsungHealthSummary, tags=["system"])
def samsung_health_sleep() -> SamsungHealthSummary:
    return SamsungHealthSummary(**get_samsung_health_summary())


@router.post("/briefings", response_model=FinalBriefing, tags=["briefings"])
def create_briefing_route(payload: BriefingRequest) -> FinalBriefing:
    return create_briefing(
        user_input=payload.user_input,
        location=payload.location,
        date=payload.date,
        user_name=payload.user_name,
    )


@router.post(
    "/agent/interpret",
    response_model=AgentInterpretResponse,
    tags=["agent"],
    responses={
        404: CALENDAR_NOT_FOUND_RESPONSE,
        502: AGENT_INTERPRET_ERROR_RESPONSE,
        503: AGENT_INTERPRET_ERROR_RESPONSE,
    },
)
def interpret_agent_route(payload: AgentInterpretRequest) -> AgentInterpretResponse:
    return interpret_agent_instruction(
        user_input=payload.input,
        date=payload.date,
        calendar_id=payload.calendar_id,
        latest_proposal_id=payload.latest_proposal_id,
    )


@router.get("/admin/summary", response_model=AdminSummary, tags=["admin"])
def admin_summary() -> AdminSummary:
    return get_admin_summary()


@router.get(
    "/presentation/demo", response_model=PresentationDemo, tags=["presentation"]
)
def presentation_demo() -> PresentationDemo:
    return get_presentation_demo()


@router.post(
    "/slack/summary",
    response_model=SlackSummaryResponse,
    tags=["slack"],
)
def slack_summary(payload: SlackSummaryRequest) -> SlackSummaryResponse:
    settings = get_settings()
    try:
        return summarize_slack_channel(
            channel_id=payload.channel_id,
            user_input=payload.user_input,
            date=payload.date or settings.default_date,
            lookback_hours=payload.lookback_hours,
        )
    except ValueError as exc:
        raise AppError(
            code="invalid_query",
            message=str(exc),
            status_code=400,
            details=[
                error_detail(
                    code="invalid_query",
                    message=str(exc),
                    field="lookback_hours",
                )
            ],
        ) from exc
    except RuntimeError as exc:
        raise AppError(
            code="slack_summary_failed",
            message=str(exc),
            status_code=502,
            details=[],
        ) from exc


@router.get(
    "/calendars",
    response_model=CalendarListResponse,
    tags=["calendars"],
    summary="List calendars",
    description="Returns the calendars currently available to the Jarvis calendar domain.",
    response_description="Available calendar records.",
    operation_id="list_calendars",
)
def list_calendars_route() -> CalendarListResponse:
    return list_calendars_response()


@router.get(
    "/calendars/{calendar_id}",
    response_model=CalendarDetailResponse,
    tags=["calendars"],
    summary="Get calendar",
    description="Returns metadata for a single calendar.",
    response_description="Calendar details.",
    operation_id="get_calendar",
    responses={404: CALENDAR_NOT_FOUND_RESPONSE},
)
def get_calendar_route(calendar_id: CalendarId) -> CalendarDetailResponse:
    return get_calendar_detail_response(calendar_id)


@router.get(
    "/calendars/{calendar_id}/events",
    response_model=CalendarEventsResponse,
    tags=["calendars"],
    summary="List calendar events",
    description=(
        "Returns events for a single day or for an inclusive start_date/end_date window. "
        "Use either date or the start_date/end_date pair."
    ),
    response_description="Calendar events for the requested window.",
    operation_id="list_calendar_events",
    responses={
        404: CALENDAR_NOT_FOUND_RESPONSE,
        422: CALENDAR_QUERY_ERROR_RESPONSE,
    },
)
def get_calendar_events_route(
    calendar_id: CalendarId,
    date_value: DateQuery = None,
    start_date: StartDateQuery = None,
    end_date: EndDateQuery = None,
) -> CalendarEventsResponse:
    response = get_calendar_events_response(
        calendar_id,
        date_value=date_value,
        start_date=start_date,
        end_date=end_date,
    )
    response.pop("range_label", None)
    return response


@router.get(
    "/calendars/{calendar_id}/conflicts",
    response_model=CalendarConflictsResponse,
    tags=["calendars"],
    summary="List calendar conflicts",
    description="Detects scheduling conflicts for the requested calendar and date window.",
    response_description="Conflict records for the requested window.",
    operation_id="list_calendar_conflicts",
    responses={
        404: CALENDAR_NOT_FOUND_RESPONSE,
        422: CALENDAR_QUERY_ERROR_RESPONSE,
    },
)
def get_calendar_conflicts_route(
    calendar_id: CalendarId,
    date_value: DateQuery = None,
    start_date: StartDateQuery = None,
    end_date: EndDateQuery = None,
) -> CalendarConflictsResponse:
    return get_calendar_conflicts_response(
        calendar_id,
        date_value=date_value,
        start_date=start_date,
        end_date=end_date,
    )


@router.get(
    "/calendars/{calendar_id}/summary",
    response_model=CalendarSummaryResponse,
    tags=["calendars"],
    summary="Get calendar summary",
    description="Builds a natural-language summary and conflict digest for the requested calendar window.",
    response_description="Calendar summary for the requested window.",
    operation_id="get_calendar_summary",
    responses={
        404: CALENDAR_NOT_FOUND_RESPONSE,
        422: CALENDAR_QUERY_ERROR_RESPONSE,
    },
)
def get_calendar_summary_route(
    calendar_id: CalendarId,
    date_value: DateQuery = None,
    start_date: StartDateQuery = None,
    end_date: EndDateQuery = None,
) -> CalendarSummaryResponse:
    return get_calendar_summary_response(
        calendar_id,
        date_value=date_value,
        start_date=start_date,
        end_date=end_date,
    )


@router.post(
    "/calendar-operations/proposals",
    response_model=CalendarOperationProposal,
    status_code=status.HTTP_201_CREATED,
    tags=["calendar-operations"],
    summary="Create calendar operation proposal",
    description=(
        "Previews a calendar mutation, returning an optimistic-concurrency snapshot hash and any warnings. "
        "The proposal must be executed separately."
    ),
    response_description="Created calendar operation proposal.",
    operation_id="create_calendar_operation_proposal",
    responses={
        404: PROPOSAL_CREATE_NOT_FOUND_RESPONSE,
        409: PROPOSAL_CREATE_CONFLICT_RESPONSE,
        422: PROPOSAL_CREATE_VALIDATION_RESPONSE,
    },
)
def create_calendar_operation_proposal_route(
    payload: CalendarOperationProposalRequest,
) -> CalendarOperationProposal:
    return create_calendar_operation_proposal(
        payload.model_dump(exclude_none=True, exclude_unset=True)
    )


@router.get(
    "/calendar-operations",
    response_model=CalendarOperationListResponse,
    tags=["calendar-operations"],
    summary="List calendar operation proposals",
    description="Returns all stored calendar operation proposals.",
    response_description="Stored calendar operation proposals.",
    operation_id="list_calendar_operation_proposals",
)
def list_calendar_operation_proposals_route() -> CalendarOperationListResponse:
    return list_calendar_operation_proposals()


@router.get(
    "/calendar-operations/{proposal_id}",
    response_model=CalendarOperationProposal,
    tags=["calendar-operations"],
    summary="Get calendar operation proposal",
    description="Returns a single stored calendar operation proposal.",
    response_description="Calendar operation proposal.",
    operation_id="get_calendar_operation_proposal",
    responses={404: PROPOSAL_NOT_FOUND_RESPONSE},
)
def get_calendar_operation_proposal_route(
    proposal_id: ProposalId,
) -> CalendarOperationProposal:
    return get_calendar_operation_proposal(proposal_id)


@router.post(
    "/calendar-operations/{proposal_id}/execute",
    response_model=CalendarOperationResult,
    tags=["calendar-operations"],
    summary="Execute calendar operation proposal",
    description=(
        "Executes a previously proposed calendar operation. The body proposal_id must match the path proposal_id, "
        "the snapshot_hash must still be current, and confirmed must be true."
    ),
    response_description="Execution result for the calendar operation proposal.",
    operation_id="execute_calendar_operation_proposal",
    responses={
        404: PROPOSAL_NOT_FOUND_RESPONSE,
        409: PROPOSAL_CONFLICT_RESPONSE,
        422: PROPOSAL_EXECUTE_VALIDATION_RESPONSE,
    },
)
def execute_calendar_operation_route(
    proposal_id: ProposalId,
    payload: CalendarOperationExecuteRequest,
) -> CalendarOperationResult:
    if payload.proposal_id != proposal_id:
        raise AppError(
            code="proposal_mismatch",
            message="The proposal_id in the body must match the path parameter.",
            status_code=409,
            details=[
                error_detail(
                    code="proposal_mismatch",
                    message="The proposal_id in the body must match the path parameter.",
                    field="proposal_id",
                )
            ],
        )

    return execute_calendar_operation(
        proposal_id=proposal_id,
        snapshot_hash=payload.snapshot_hash,
        confirmed=payload.confirmed,
    )


@router.post(
    "/calendar-operations/{proposal_id}/reject",
    response_model=CalendarOperationResult,
    tags=["calendar-operations"],
    summary="Reject calendar operation proposal",
    description=(
        "Marks a previously proposed calendar operation as rejected without applying it. "
        "The body proposal_id must match the path proposal_id."
    ),
    response_description="Rejection result for the calendar operation proposal.",
    operation_id="reject_calendar_operation_proposal",
    responses={
        404: PROPOSAL_NOT_FOUND_RESPONSE,
        409: PROPOSAL_CONFLICT_RESPONSE,
        422: PROPOSAL_REJECT_VALIDATION_RESPONSE,
    },
)
def reject_calendar_operation_route(
    proposal_id: ProposalId,
    payload: CalendarOperationRejectRequest,
) -> CalendarOperationResult:
    if payload.proposal_id != proposal_id:
        raise AppError(
            code="proposal_mismatch",
            message="The proposal_id in the body must match the path parameter.",
            status_code=409,
            details=[
                error_detail(
                    code="proposal_mismatch",
                    message="The proposal_id in the body must match the path parameter.",
                    field="proposal_id",
                )
            ],
        )

    return reject_calendar_operation(
        proposal_id=proposal_id,
        reason=payload.reason,
    )


@router.get(
    "/calendar-operation-audit",
    response_model=CalendarAuditResponse,
    tags=["calendar-operations"],
    summary="List calendar operation audit records",
    description="Returns the persisted audit trail for executed or rejected calendar operations.",
    response_description="Calendar operation audit records.",
    operation_id="list_calendar_operation_audit_records",
)
def get_calendar_operation_audit_route() -> CalendarAuditResponse:
    return get_calendar_audit_log()
