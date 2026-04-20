from __future__ import annotations

from enum import StrEnum
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field, model_validator


class FeatureResponse(BaseModel):
    owner: str = Field(description="Feature owner or owning domain.")
    feature: str = Field(
        description="Stable feature identifier for the response payload."
    )
    uses_mock: bool = Field(
        default=True, description="Whether the payload was produced from mock data."
    )


class HealthResponse(BaseModel):
    status: str = Field(description="Overall API health status.", examples=["ok"])
    use_mocks: bool = Field(
        description="Whether the backend is currently serving mock integrations."
    )
    samsung_health_use_mock: bool = Field(
        description="Whether the Samsung Health integration is currently serving mock data."
    )
    model: str = Field(
        description="Configured primary LLM model identifier.",
        examples=["gpt-5.1-mini"],
    )


class ErrorDetail(BaseModel):
    model_config = ConfigDict(extra="forbid")

    field: str | None = Field(
        default=None,
        description="Request field or parameter associated with the error, when applicable.",
        examples=["proposal_id"],
    )
    message: str = Field(
        description="Human-readable explanation for the individual validation or conflict detail.",
        examples=["The proposal_id in the body must match the path parameter."],
    )
    code: str = Field(
        description="Stable machine-readable detail code.",
        examples=["proposal_mismatch"],
    )


class ErrorContent(BaseModel):
    model_config = ConfigDict(extra="forbid")

    code: str = Field(
        description="Stable machine-readable error code.", examples=["invalid_query"]
    )
    message: str = Field(
        description="Human-readable summary of the failure.",
        examples=["Use either date or start_date/end_date, not both."],
    )
    details: list[ErrorDetail] = Field(
        default_factory=list,
        description="Optional field-level or sub-error metadata.",
    )


class ErrorResponse(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {
                    "error": {
                        "code": "invalid_query",
                        "message": "Use either date or start_date/end_date, not both.",
                        "details": [],
                    }
                }
            ]
        },
    )

    error: ErrorContent = Field(
        description="Standard error envelope returned for non-2xx responses."
    )


class WeatherBrief(FeatureResponse):
    location: str
    date: str
    summary: str
    temperature_c: float
    condition: str
    recommendation: str
    items: list[str]


class CalendarInfo(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "primary",
                    "name": "Primary Calendar",
                    "timezone": "Asia/Seoul",
                    "is_primary": True,
                    "uses_mock": True,
                }
            ]
        }
    )

    id: str = Field(description="Opaque calendar identifier.", examples=["primary"])
    name: str = Field(
        description="Human-readable calendar name.", examples=["Primary Calendar"]
    )
    timezone: str = Field(
        description="IANA timezone for the calendar.", examples=["Asia/Seoul"]
    )
    is_primary: bool = Field(
        default=False, description="Whether this calendar is the default calendar."
    )
    uses_mock: bool = Field(
        default=True, description="Whether the calendar record comes from mock data."
    )


class CalendarEvent(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "evt-review-1",
                    "calendar_id": "primary",
                    "title": "Customer Review",
                    "start": "2026-04-18T13:00:00+09:00",
                    "end": "2026-04-18T14:00:00+09:00",
                    "description": "Monthly customer success review.",
                    "location": "Office",
                    "priority": "high",
                    "all_day": False,
                    "recurring": False,
                    "recurrence_rule": None,
                    "recurrence_interval_days": None,
                    "recurrence_count": None,
                    "series_id": None,
                }
            ]
        }
    )

    id: str = Field(description="Event identifier.", examples=["evt-review-1"])
    calendar_id: str = Field(
        description="Calendar that owns the event.", examples=["primary"]
    )
    title: str = Field(description="Event title.", examples=["Customer Review"])
    start: str = Field(
        description="Inclusive event start timestamp in ISO 8601 format.",
        examples=["2026-04-18T13:00:00+09:00"],
    )
    end: str = Field(
        description="Exclusive event end timestamp in ISO 8601 format.",
        examples=["2026-04-18T14:00:00+09:00"],
    )
    description: str | None = Field(
        default=None, description="Optional event description."
    )
    location: str | None = Field(
        default=None, description="Optional event location.", examples=["Office"]
    )
    priority: str = Field(
        default="medium",
        description="Priority label used by the calendar UI.",
        examples=["medium"],
    )
    all_day: bool = Field(
        default=False, description="Whether the event spans an entire calendar day."
    )
    recurring: bool = Field(
        default=False, description="Whether the event belongs to a recurrence series."
    )
    recurrence_rule: str | None = Field(
        default=None, description="Optional recurrence rule string."
    )
    recurrence_interval_days: int | None = Field(
        default=None, description="Interval between recurring occurrences, in days."
    )
    recurrence_count: int | None = Field(
        default=None, description="Number of generated recurring occurrences."
    )
    series_id: str | None = Field(
        default=None,
        description="Shared series identifier for recurring events.",
        examples=["series-team-sync"],
    )


class CalendarConflict(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "type": "overlap",
                    "message": "Customer Review overlaps with Team Sync.",
                    "severity": "warning",
                    "event_ids": ["evt-review-1", "evt-sync-2"],
                }
            ]
        }
    )

    type: str = Field(description="Conflict classifier.", examples=["overlap"])
    message: str = Field(description="Human-readable conflict description.")
    severity: str = Field(description="Conflict severity.", examples=["warning"])
    event_ids: list[str] = Field(
        default_factory=list, description="Event identifiers involved in the conflict."
    )


class CalendarBrief(FeatureResponse):
    calendar_id: str
    date: str
    summary: str
    events: list[CalendarEvent]
    conflicts: list[CalendarConflict]


class CalendarListResponse(FeatureResponse):
    calendars: list[CalendarInfo] = Field(
        description="Calendars available to the caller."
    )


class CalendarDetailResponse(FeatureResponse):
    calendar: CalendarInfo = Field(description="Requested calendar record.")


class CalendarEventsResponse(FeatureResponse):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "owner": "calendar",
                    "feature": "calendar",
                    "uses_mock": True,
                    "calendar": {
                        "id": "primary",
                        "name": "Primary Calendar",
                        "timezone": "Asia/Seoul",
                        "is_primary": True,
                        "uses_mock": True,
                    },
                    "events": [
                        {
                            "id": "evt-review-1",
                            "calendar_id": "primary",
                            "title": "Customer Review",
                            "start": "2026-04-18T13:00:00+09:00",
                            "end": "2026-04-18T14:00:00+09:00",
                            "description": "Monthly customer success review.",
                            "location": "Office",
                            "priority": "high",
                            "all_day": False,
                            "recurring": False,
                            "recurrence_rule": None,
                            "recurrence_interval_days": None,
                            "recurrence_count": None,
                            "series_id": None,
                        }
                    ],
                }
            ]
        }
    )

    calendar: CalendarInfo = Field(description="Calendar the events belong to.")
    events: list[CalendarEvent] = Field(
        description="Events in the requested date window."
    )


class CalendarConflictsResponse(FeatureResponse):
    calendar: CalendarInfo = Field(
        description="Calendar that was inspected for conflicts."
    )
    conflicts: list[CalendarConflict] = Field(
        description="Conflicts detected in the requested date window."
    )


class CalendarSummaryResponse(FeatureResponse):
    calendar: CalendarInfo = Field(description="Calendar covered by the summary.")
    date: str = Field(
        description="Resolved date label for the requested time window.",
        examples=["2026-04-18"],
    )
    summary: str = Field(
        description="Natural-language summary for the requested time window."
    )
    events: list[CalendarEvent] = Field(
        description="Events included in the summary window."
    )
    conflicts: list[CalendarConflict] = Field(
        description="Conflicts considered when producing the summary."
    )


class RecurringEditScope(StrEnum):
    OCCURRENCE = "occurrence"
    FOLLOWING = "following"
    SERIES = "series"


class CalendarOperationType(StrEnum):
    CREATE_EVENT = "create_event"
    UPDATE_EVENT = "update_event"
    MOVE_EVENT = "move_event"
    DELETE_EVENT = "delete_event"
    CREATE_CALENDAR = "create_calendar"
    DELETE_CALENDAR = "delete_calendar"


class CalendarOperationStatus(StrEnum):
    PROPOSED = "proposed"
    EXECUTED = "executed"
    REJECTED = "rejected"
    STALE = "stale"
    FAILED = "failed"


class CalendarEventMutation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str | None = Field(
        default=None, description="Event title for create or update operations."
    )
    start: str | None = Field(
        default=None,
        description="Event start timestamp in ISO 8601 format.",
        examples=["2026-04-18T13:00:00+09:00"],
    )
    end: str | None = Field(
        default=None,
        description="Event end timestamp in ISO 8601 format.",
        examples=["2026-04-18T14:00:00+09:00"],
    )
    description: str | None = Field(
        default=None, description="Optional event description."
    )
    location: str | None = Field(
        default=None, description="Optional event location.", examples=["Office"]
    )
    priority: str | None = Field(
        default=None, description="Optional priority label.", examples=["high"]
    )
    all_day: bool = Field(default=False, description="Set to true for all-day events.")
    recurring: bool = Field(
        default=False, description="Set to true when creating a recurring event series."
    )
    recurrence_rule: str | None = Field(
        default=None, description="Optional recurrence rule string."
    )
    recurrence_interval_days: int | None = Field(
        default=None, description="Recurring interval in days when recurring is true."
    )
    recurrence_count: int | None = Field(
        default=None,
        description="Number of occurrences to create when recurring is true.",
    )
    series_id: str | None = Field(
        default=None,
        description="Existing series identifier when targeting a recurring series.",
    )


class CalendarMutation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(
        description="Calendar display name.", examples=["Customer Success"]
    )
    timezone: str = Field(
        default="Asia/Seoul",
        description="IANA timezone for the calendar.",
        examples=["Asia/Seoul"],
    )
    is_primary: bool = Field(
        default=False, description="Whether the created calendar should become primary."
    )


class CalendarOperationProposalRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {
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
                }
            ]
        },
    )

    operation_type: CalendarOperationType = Field(
        description="Requested calendar operation type."
    )
    actor: str = Field(
        default="agent",
        description="Actor responsible for proposing the operation.",
        examples=["agent"],
    )
    calendar_id: str | None = Field(
        default="primary",
        description="Target calendar identifier.",
        examples=["primary"],
    )
    event_id: str | None = Field(
        default=None,
        description="Target event identifier for update, move, or delete operations.",
    )
    recurring_scope: RecurringEditScope | None = Field(
        default=None,
        description="Required when editing or deleting a recurring event.",
    )
    event: CalendarEventMutation | None = Field(
        default=None, description="Event mutation payload for event operations."
    )
    calendar: CalendarMutation | None = Field(
        default=None, description="Calendar mutation payload for calendar operations."
    )

    @model_validator(mode="after")
    def validate_payload(self) -> "CalendarOperationProposalRequest":
        event_ops = {
            CalendarOperationType.CREATE_EVENT,
            CalendarOperationType.UPDATE_EVENT,
            CalendarOperationType.MOVE_EVENT,
            CalendarOperationType.DELETE_EVENT,
        }

        if (
            self.operation_type in event_ops
            and self.operation_type != CalendarOperationType.DELETE_EVENT
        ):
            if self.event is None:
                raise ValueError("event payload is required for this operation")

        if (
            self.operation_type
            in {
                CalendarOperationType.UPDATE_EVENT,
                CalendarOperationType.MOVE_EVENT,
                CalendarOperationType.DELETE_EVENT,
            }
            and not self.event_id
        ):
            raise ValueError("event_id is required for this operation")

        if (
            self.operation_type == CalendarOperationType.CREATE_CALENDAR
            and self.calendar is None
        ):
            raise ValueError("calendar payload is required for create_calendar")

        if (
            self.operation_type == CalendarOperationType.DELETE_CALENDAR
            and not self.calendar_id
        ):
            raise ValueError("calendar_id is required for delete_calendar")

        if self.event and self.event.recurring:
            if not self.event.recurrence_count or self.event.recurrence_count < 1:
                raise ValueError("recurrence_count must be set when recurring is true")
            if (
                not self.event.recurrence_interval_days
                or self.event.recurrence_interval_days < 1
            ):
                raise ValueError(
                    "recurrence_interval_days must be set when recurring is true"
                )

        return self


class CalendarOperationProposal(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "proposal_id": "prop-abc123def456",
                    "operation_type": "create_event",
                    "status": "proposed",
                    "actor": "agent",
                    "target_summary": "Create event 'Customer Review' in calendar 'primary'.",
                    "calendar_id": "primary",
                    "event_id": None,
                    "recurring_scope": None,
                    "requires_confirmation": True,
                    "warnings": [],
                    "before_state": None,
                    "after_state": {
                        "events": [
                            {
                                "id": "evt-review-1",
                                "calendar_id": "primary",
                                "title": "Customer Review",
                                "start": "2026-04-18T13:00:00+09:00",
                                "end": "2026-04-18T14:00:00+09:00",
                                "description": None,
                                "location": "Office",
                                "priority": "high",
                                "all_day": False,
                                "recurring": False,
                                "recurrence_rule": None,
                                "recurrence_interval_days": None,
                                "recurrence_count": None,
                                "series_id": None,
                            }
                        ]
                    },
                    "snapshot_hash": "5bb2ae0f4d4a9330",
                    "created_at": "2026-04-18T03:30:00Z",
                    "executed_at": None,
                    "error_message": None,
                }
            ]
        }
    )

    proposal_id: str = Field(
        description="Proposal identifier.", examples=["prop-abc123def456"]
    )
    operation_type: CalendarOperationType = Field(
        description="Proposed calendar operation type."
    )
    status: CalendarOperationStatus = Field(
        description="Current execution status of the proposal."
    )
    actor: str = Field(
        description="Actor that created the proposal.", examples=["agent"]
    )
    target_summary: str = Field(
        description="Human-readable summary of the operation target."
    )
    calendar_id: str | None = Field(
        default=None, description="Target calendar identifier, when applicable."
    )
    event_id: str | None = Field(
        default=None, description="Target event identifier, when applicable."
    )
    recurring_scope: RecurringEditScope | None = Field(
        default=None, description="Applied recurring edit scope, when applicable."
    )
    requires_confirmation: bool = Field(
        default=True,
        description="Whether an explicit execute confirmation is required.",
    )
    warnings: list[str] = Field(
        default_factory=list,
        description="Non-fatal warnings generated during proposal preview.",
    )
    before_state: dict[str, Any] | None = Field(
        default=None, description="Projected state before the operation executes."
    )
    after_state: dict[str, Any] | None = Field(
        default=None, description="Projected state after the operation executes."
    )
    snapshot_hash: str = Field(
        description="Optimistic concurrency snapshot tied to the proposal."
    )
    created_at: str = Field(
        description="Proposal creation timestamp in ISO 8601 format."
    )
    executed_at: str | None = Field(
        default=None, description="Execution timestamp in ISO 8601 format, if executed."
    )
    error_message: str | None = Field(
        default=None, description="Execution failure message, when applicable."
    )


class CalendarOperationExecuteRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {
                    "proposal_id": "prop-abc123def456",
                    "snapshot_hash": "5bb2ae0f4d4a9330",
                    "confirmed": True,
                }
            ]
        },
    )

    proposal_id: str = Field(
        description="Proposal identifier that must match the path parameter."
    )
    snapshot_hash: str = Field(
        description="Snapshot hash returned by the proposal preview."
    )
    confirmed: bool = Field(
        default=True, description="Must be true to execute a proposal."
    )


class CalendarOperationRejectRequest(BaseModel):
    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [
                {
                    "proposal_id": "prop-abc123def456",
                    "reason": "User rejected the suggested change.",
                }
            ]
        },
    )

    proposal_id: str = Field(
        description="Proposal identifier that must match the path parameter."
    )
    reason: str | None = Field(
        default=None,
        description="Optional rejection reason recorded in the proposal and audit log.",
    )


class CalendarOperationResult(BaseModel):
    proposal_id: str = Field(description="Executed proposal identifier.")
    operation_type: CalendarOperationType = Field(
        description="Executed calendar operation type."
    )
    status: CalendarOperationStatus = Field(description="Execution result status.")
    target_summary: str = Field(
        description="Human-readable summary of the executed target."
    )
    snapshot_hash: str = Field(
        description="Snapshot hash that was validated for execution."
    )
    executed_at: str = Field(description="Execution timestamp in ISO 8601 format.")


class CalendarOperationListResponse(FeatureResponse):
    operations: list[CalendarOperationProposal] = Field(
        description="Stored calendar operation proposals."
    )


class CalendarAuditRecord(BaseModel):
    audit_id: str = Field(description="Audit record identifier.")
    proposal_id: str = Field(
        description="Proposal identifier associated with the audit record."
    )
    operation_type: CalendarOperationType = Field(
        description="Operation type captured by the audit record."
    )
    actor: str = Field(description="Actor that initiated the proposal.")
    calendar_id: str | None = Field(
        default=None, description="Target calendar identifier, when applicable."
    )
    event_id: str | None = Field(
        default=None, description="Target event identifier, when applicable."
    )
    recurring_scope: RecurringEditScope | None = Field(
        default=None, description="Recurring scope that was applied, when applicable."
    )
    warnings: list[str] = Field(
        default_factory=list,
        description="Warnings present when the audit record was written.",
    )
    before_state: dict[str, Any] | None = Field(
        default=None, description="Captured state before execution."
    )
    after_state: dict[str, Any] | None = Field(
        default=None, description="Captured state after execution."
    )
    result_status: CalendarOperationStatus = Field(
        description="Final result status recorded in the audit log."
    )
    error_message: str | None = Field(
        default=None,
        description="Failure message when the operation did not complete successfully.",
    )
    recorded_at: str = Field(description="Audit record timestamp in ISO 8601 format.")


class CalendarAuditResponse(FeatureResponse):
    records: list[CalendarAuditRecord] = Field(
        description="Calendar operation audit records."
    )


class AgentInterpretStatus(StrEnum):
    INTERPRETED = "interpreted"
    CLARIFY = "clarify"


class AgentInterpretRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    input: str = Field(
        min_length=1,
        description="Natural-language calendar instruction from the UI.",
        examples=["Change the 기획리뷰. Defer it 30 minutes."],
    )
    date: str = Field(
        description="Date context used to resolve relative scheduling requests.",
        examples=["2026-04-18"],
    )
    calendar_id: str = Field(
        default="primary",
        description="Calendar context used to resolve event references.",
        examples=["primary"],
    )
    latest_proposal_id: str | None = Field(
        default=None,
        description="Most recent proposal identifier available in the UI, when present.",
        examples=["prop-abc123def456"],
    )


class AgentInterpretResponse(FeatureResponse):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "owner": "agent",
                    "feature": "agent_interpreter",
                    "uses_mock": True,
                    "status": "interpreted",
                    "source": "openrouter",
                    "command": "move event evt-3 to 2026-04-18 from 15:30 to 16:30 calendar primary",
                    "explanation": "Matched '기획리뷰' to evt-3 and shifted the meeting by 30 minutes.",
                }
            ]
        }
    )

    status: AgentInterpretStatus = Field(
        description="Whether the instruction was interpreted or needs clarification."
    )
    source: str = Field(
        description="Interpreter source used to resolve the instruction.",
        examples=["openrouter"],
    )
    command: str | None = Field(
        default=None,
        description="Normalized command string that matches the frontend command grammar.",
    )
    explanation: str = Field(
        description="Human-readable explanation of the resolution or clarification request."
    )


class SlackChannelSummary(BaseModel):
    channel: str
    summary: str
    action_items: list[str] = Field(default_factory=list)


class SlackMessage(BaseModel):
    user: str
    text: str
    ts: str


class SlackBrief(FeatureResponse):
    date: str
    summary: str
    channels: list[SlackChannelSummary]

class SlackSummaryRequest(BaseModel):
    channel_id: str = Field(
        min_length=1, description="Slack channel ID such as C0123456789"
    )
    user_input: str = Field(default="최근 1일 대화 핵심만 5줄로 요약해줘")
    date: str | None = Field(default=None, description="브리핑 기준 날짜")
    lookback_hours: int = Field(
        default=24, ge=1, le=168, description="몇 시간치 메시지를 읽을지"
    )

class SlackSummaryResponse(FeatureResponse):
    date: str
    channel_id: str
    channel_name: str
    lookback_hours: int
    message_count: int
    summary: str
    summary_lines: list[str]
    messages: list[SlackMessage]
    model: str

class AdminMetric(BaseModel):
    feature: str
    owner: str
    token_estimate: int
    latency_ms: int
    status: str


class AdminNode(BaseModel):
    id: str
    label: str
    group: str


class AdminEdge(BaseModel):
    source: str
    target: str
    label: str


class AdminSummary(FeatureResponse):
    summary: str
    top_token_feature: str
    metrics: list[AdminMetric]
    flow_nodes: list[AdminNode]
    flow_edges: list[AdminEdge]


class PresentationCard(BaseModel):
    title: str
    description: str
    talking_points: list[str]


class PresentationDemo(FeatureResponse):
    demo_title: str
    cards: list[PresentationCard]
    closing_message: str


class SamsungHealthDataTypePlan(BaseModel):
    key: str = Field(description="Samsung Health data type key or product-facing alias.")
    label: str = Field(description="Display label for the data type.")
    priority: str = Field(description="Suggested implementation priority.", examples=["high"])
    reason: str = Field(description="Why this data type is useful for the briefing experience.")


class SamsungHealthBridgePayload(BaseModel):
    model_config = ConfigDict(
        extra="allow",
        json_schema_extra={
            "examples": [
                {
                    "health_data_type": "com.samsung.health.sleep",
                    "detected_at": "2026-04-18T07:12:00+09:00",
                    "status": "awake",
                    "items": [
                        {
                            "start_time": 1776440880000,
                            "end_time": 1776467100000,
                            "time_offset": 32400000,
                            "comment": "Samsung Health sleep session imported from Android bridge.",
                        }
                    ],
                }
            ]
        },
    )

    health_data_type: str = Field(
        default="com.samsung.health.sleep",
        description="Samsung Health SDK data type identifier from the Android bridge.",
    )
    detected_at: str | None = Field(
        default=None,
        description="Bridge-side detection timestamp in ISO 8601 format.",
    )
    range_days: int = Field(
        default=7,
        ge=1,
        le=30,
        description="How many recent days of Samsung Health data the bridge attempted to upload.",
    )
    status: str | None = Field(
        default=None,
        description="Bridge-side derived status such as awake or sleeping.",
    )
    items: list[dict[str, Any]] = Field(
        default_factory=list,
        description="Raw Samsung Health record list from the Android bridge.",
    )


class SamsungHealthSleepHistoryItem(BaseModel):
    sleep_start: str
    sleep_end: str
    wake_time: str
    sleep_duration_minutes: int
    status: str


class SamsungHealthSummary(BaseModel):
    source: str
    uses_mock: bool = True
    integration_mode: str = Field(
        description="How the backend expects Samsung Health data to arrive.",
        examples=["android_sdk_bridge"],
    )
    partnership_required: bool = Field(
        description="Whether production use requires Samsung Health partnership approval."
    )
    developer_mode_supported: bool = Field(
        description="Whether Samsung Health developer mode can be used before partnership approval."
    )
    health_data_type: str = Field(
        description="Primary Samsung Health data type used by this endpoint.",
        examples=["com.samsung.health.sleep"],
    )
    planned_data_types: list[SamsungHealthDataTypePlan] = Field(
        default_factory=list,
        description="Recommended Samsung Health data types to expand next.",
    )
    range_days: int = Field(
        default=7,
        description="How many recent days of Samsung Health data were considered in this summary.",
    )
    recent_nights_count: int = Field(
        default=0,
        description="How many sleep sessions were included in the current summary window.",
    )
    detected_at: str
    wake_time: Optional[str] = None
    sleep_start: Optional[str] = None
    sleep_end: Optional[str] = None
    sleep_duration_minutes: Optional[int] = None
    average_sleep_duration_minutes: Optional[int] = None
    average_wake_time: Optional[str] = None
    sleep_debt_minutes_vs_target: Optional[int] = None
    sleep_history: list[SamsungHealthSleepHistoryItem] = Field(
        default_factory=list,
        description="Recent sleep sessions normalized for assistant features.",
    )
    assistant_actions: list[str] = Field(
        default_factory=list,
        description="Concrete assistant-app actions or prompts that can be driven by this data.",
    )
    today_sleep_recommendation: Optional[str] = Field(
        default=None,
        description="A simple bedtime or recovery recommendation for today's briefing.",
    )
    status: str
    summary: str
    integration_notes: str = Field(
        description="Implementation notes for SDK setup, partnership, and Android bridge assumptions."
    )

class BriefingRequest(BaseModel):
    user_input: str = Field(default="오늘 아침 브리핑 해줘")
    location: str = Field(default="Seoul")
    date: str = Field(default="2026-04-18")
    user_name: str = Field(default="Team Jarvis")


class FinalBriefing(BaseModel):
    headline: str
    generated_for: str
    user_input: str
    weather: WeatherBrief
    calendar: CalendarBrief
    slack: SlackBrief
    admin: AdminSummary
    presentation: PresentationDemo
    final_summary: str
