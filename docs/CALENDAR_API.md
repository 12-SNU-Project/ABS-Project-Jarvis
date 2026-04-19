# Calendar API Reference

This document describes the calendar feature exactly as it is shipped on `feature/calendar` today. It covers the deterministic read surface, the proposal-first managed-write surface, runtime validation rules enforced in service code, and the generated OpenAPI contract exposed at `/openapi.json`.

Base path: `/api/v1`

Authentication in the current branch: none. The calendar routes are an internal, mock-backed API surface.

## Sources Of Truth

- Route definitions: `backend/app/api/endpoints.py`
- Response and request models: `backend/app/schemas/schemas.py`
- Runtime validation and lifecycle logic: `backend/app/services/calendar.py`
- Persistence behavior: `backend/app/providers/calendar_provider.py`
- Generated OpenAPI schema: `GET /openapi.json`

## Shared Response Envelopes

Calendar read and list endpoints share these top-level fields:

| Field | Type | Current shipped value / behavior |
|---|---|---|
| `owner` | `string` | Always `""` in this branch |
| `feature` | `string` | Always `"calendar"` |
| `uses_mock` | `boolean` | Always `true` |

The managed-write list and audit endpoints reuse the same envelope fields. Proposal creation, proposal detail, and execute responses return dedicated operation objects instead of the feature envelope.

## Runtime Error Envelope

Calendar routes use the app-wide error envelope:

```json
{
  "error": {
    "code": "invalid_query",
    "message": "Use either date or start_date/end_date, not both.",
    "details": []
  }
}
```

Important OpenAPI note: the generated schema for the shipped calendar routes already uses `ErrorResponse` for the documented `404`, `409`, and `422` branches and includes example payloads for the major failure cases. The remaining gap is that OpenAPI still cannot encode every operation-specific runtime invariant as JSON Schema.

## Read API

### `GET /api/v1/calendars`

Lists calendars available from the current provider. Results are sorted by `calendar.id`.

#### Success response

```json
{
  "owner": "",
  "feature": "calendar",
  "uses_mock": true,
  "calendars": [
    {
      "id": "primary",
      "name": "Primary Calendar",
      "timezone": "Asia/Seoul",
      "is_primary": true,
      "uses_mock": true
    }
  ]
}
```

### `GET /api/v1/calendars/{calendar_id}`

Returns one calendar descriptor.

#### Path parameters

| Name | Type | Notes |
|---|---|---|
| `calendar_id` | `string` | Non-empty identifier |

#### Response model

`CalendarDetailResponse`

| Field | Type |
|---|---|
| `calendar` | `CalendarInfo` |

#### Failure modes

- `404 calendar_not_found`

### `GET /api/v1/calendars/{calendar_id}/events`

Returns events whose time range overlaps the requested window. The filter is not "starts within window"; it includes any event where `event.end > window_start` and `event.start < window_end`.

#### Query parameters

| Name | Type | Required | Behavior |
|---|---|---|---|
| `date` | `YYYY-MM-DD` string | No | Single-day query |
| `start_date` | `YYYY-MM-DD` string | No | Start of inclusive date range |
| `end_date` | `YYYY-MM-DD` string | No | End of inclusive date range |

#### Query resolution rules

- `date` cannot be combined with `start_date` or `end_date`.
- `start_date` and `end_date` must be supplied together.
- `end_date` must be on or after `start_date`.
- If no query is supplied, the route falls back to `JARVIS_DEFAULT_DATE`; if that env var is unset, settings default to the current system date.
- Date parsing is service-level, not schema-level. Invalid dates return `422 invalid_date`.

#### Response model

`CalendarEventsResponse`

| Field | Type | Notes |
|---|---|---|
| `calendar` | `CalendarInfo` | Calendar metadata |
| `events` | `CalendarEvent[]` | Sorted by `start` |

`CalendarEvent` fields:

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | Seed events start with `evt-`; generated events also use `evt-...` |
| `calendar_id` | `string` | Calendar identifier |
| `title` | `string` | Event title |
| `start` | ISO 8601 datetime string | Includes timezone offset |
| `end` | ISO 8601 datetime string | Includes timezone offset |
| `description` | `string | null` | Optional |
| `location` | `string | null` | Optional |
| `priority` | `string` | Normalized to `"medium"` if missing or `null` in persisted state |
| `all_day` | `boolean` | Default `false` |
| `recurring` | `boolean` | Default `false` |
| `recurrence_rule` | `string | null` | Optional |
| `recurrence_interval_days` | `integer | null` | Present for recurring events |
| `recurrence_count` | `integer | null` | Present for recurring events |
| `series_id` | `string | null` | Shared across recurring series |

Internal note: the service computes an internal `range_label`, but the route removes it before returning the response. It is intentionally absent from the shipped JSON contract and the OpenAPI schema.

#### Example

```bash
curl "http://localhost:8000/api/v1/calendars/primary/events?date=2026-04-18"
```

#### Failure modes

- `404 calendar_not_found`
- `422 invalid_query`
- `422 invalid_date`

### `GET /api/v1/calendars/{calendar_id}/conflicts`

Uses the same query contract as `/events`, but returns only conflict objects derived from the filtered event set.

#### Response model

`CalendarConflictsResponse`

| Field | Type |
|---|---|
| `calendar` | `CalendarInfo` |
| `conflicts` | `CalendarConflict[]` |

`CalendarConflict` fields:

| Field | Type | Notes |
|---|---|---|
| `type` | `string` | Currently `overlap` or `tight_buffer` |
| `message` | `string` | Human-readable explanation |
| `severity` | `string` | Currently `high` for overlap, `medium` for tight buffer |
| `event_ids` | `string[]` | Two event ids involved in the conflict |

#### Conflict rules

- `overlap`: the next event starts before the previous event ends
- `tight_buffer`: the gap between adjacent events is less than 30 minutes

#### Failure modes

- `404 calendar_not_found`
- `422 invalid_query`
- `422 invalid_date`

### `GET /api/v1/calendars/{calendar_id}/summary`

Uses the same query contract as `/events`, then combines the event list and conflict list into a single deterministic summary payload.

#### Response model

`CalendarSummaryResponse`

| Field | Type | Notes |
|---|---|---|
| `calendar` | `CalendarInfo` | Calendar metadata |
| `date` | `string` | Echoes `date`, or the `start_date`, or the configured default date |
| `summary` | `string` | Deterministic sentence built from event count, high-priority count, and conflict count |
| `events` | `CalendarEvent[]` | Same structure as `/events` |
| `conflicts` | `CalendarConflict[]` | Same structure as `/conflicts` |

Behavior details:

- Empty windows return `No scheduled events found for {label}.`
- Range queries use the start date as the `date` label and in the summary sentence. The end date is not echoed separately.

#### Failure modes

- `404 calendar_not_found`
- `422 invalid_query`
- `422 invalid_date`

## Briefing Integration

### `POST /api/v1/briefings`

The calendar feature also ships as part of the top-level briefing payload. The calendar subsection is a `CalendarBrief` built from `get_calendar_summary_response("primary", date_value=date)`.

#### Request body

```json
{
  "user_input": "오늘 아침 브리핑 해줘",
  "location": "Seoul",
  "date": "2026-04-18",
  "user_name": "Team Jarvis"
}
```

#### Calendar subsection in the response

| Field | Type | Notes |
|---|---|---|
| `calendar_id` | `string` | Defaults to `"primary"` in the current implementation |
| `date` | `string` | Requested briefing date |
| `summary` | `string` | Same deterministic summary logic as `/summary` |
| `events` | `CalendarEvent[]` | Same event shape as read API |
| `conflicts` | `CalendarConflict[]` | Same conflict shape as read API |

## Managed-Write API

The shipped write surface is proposal-first. Nothing mutates on proposal creation.

### Write lifecycle

1. Caller sends a structured proposal request.
2. The service validates the request, previews the change against a cloned state snapshot, and stores a proposal.
3. The API returns a `proposal_id`, `snapshot_hash`, optional warnings, and before/after preview state.
4. Caller sends an execute request with the same `proposal_id`, the exact `snapshot_hash`, and `confirmed=true`.
5. The service re-checks proposal status and current schedule hash before mutating.
6. On success, the proposal becomes `executed` and an audit record is appended.
7. If the schedule changed after proposal creation, the proposal becomes `stale`, execution fails with `409`, and an audit record is still appended.

### Supported `operation_type` values

- `create_event`
- `update_event`
- `move_event`
- `delete_event`
- `create_calendar`
- `delete_calendar`

### `POST /api/v1/calendar-operations/proposals`

Creates a proposal and persists it in state. Returns `201 Created`.

#### OpenAPI request model

`CalendarOperationProposalRequest`

| Field | Type | OpenAPI default | Runtime behavior |
|---|---|---|---|
| `operation_type` | enum | none | Required |
| `actor` | `string` | `"agent"` | Defaults to `"agent"` if omitted |
| `calendar_id` | `string | null` | `"primary"` | Operations target `"primary"` if omitted |
| `event_id` | `string | null` | none | Required for update, move, and delete event |
| `recurring_scope` | enum `occurrence|following|series` or `null` | none | Required when mutating a recurring event |
| `event` | `CalendarEventMutation | null` | none | Required for create/update/move event |
| `calendar` | `CalendarMutation | null` | none | Required for create calendar |

Important nuance: the route serializes the Pydantic model with `exclude_unset=True`. If a caller omits `calendar_id`, the service still targets `"primary"`, but the persisted proposal's `calendar_id` field may be `null` because the omitted default is not echoed back into `request_payload`.

#### Runtime validation matrix

| Operation | Required request parts | Notes |
|---|---|---|
| `create_event` | `event.title`, `event.start`, `event.end` | `calendar_id` falls back to `primary` |
| `update_event` | `event_id`, non-empty `event` | `move_event` shares this exact implementation |
| `move_event` | `event_id`, non-empty `event` | No separate move-specific schema exists |
| `delete_event` | `event_id` | No `event` payload required |
| `create_calendar` | `calendar.name` | `calendar.timezone` defaults to `Asia/Seoul` |
| `delete_calendar` | `calendar_id` | Cannot delete `primary` in mock mode |

Recurring event rules:

- If the target event is recurring and `recurring_scope` is omitted, the API returns `422 recurring_scope_required`.
- If `event.recurring` is `true` on creation or update, both `recurrence_count` and `recurrence_interval_days` must be present and greater than zero.

Event payload rules:

- `start` and `end` must be valid ISO 8601 datetimes when supplied.
- If both are supplied, `end` must be after `start`.
- Update and move requests must provide at least one non-null event field.

#### `CalendarEventMutation`

All fields are optional in the OpenAPI schema, but service logic imposes operation-specific rules.

| Field | Type | Default / behavior |
|---|---|---|
| `title` | `string | null` | Optional |
| `start` | `string | null` | ISO 8601 datetime when present |
| `end` | `string | null` | ISO 8601 datetime when present |
| `description` | `string | null` | Optional |
| `location` | `string | null` | Optional |
| `priority` | `string | null` | Normalized to `"medium"` if omitted on create |
| `all_day` | `boolean` | Defaults to `false` |
| `recurring` | `boolean` | Defaults to `false` |
| `recurrence_rule` | `string | null` | Optional |
| `recurrence_interval_days` | `integer | null` | Required when `recurring=true` |
| `recurrence_count` | `integer | null` | Required when `recurring=true` |
| `series_id` | `string | null` | Optional; generated automatically for recurring create if omitted |

#### `CalendarMutation`

| Field | Type | Default / behavior |
|---|---|---|
| `name` | `string` | Required |
| `timezone` | `string` | Defaults to `Asia/Seoul` |
| `is_primary` | `boolean` | Defaults to `false` |

#### Proposal response

`CalendarOperationProposal`

| Field | Type | Notes |
|---|---|---|
| `proposal_id` | `string` | Generated as `prop-<12 hex chars>` |
| `operation_type` | enum | Copied from request |
| `status` | enum | Starts as `proposed` |
| `actor` | `string` | Defaults to `agent` if omitted |
| `target_summary` | `string` | Deterministic summary string |
| `calendar_id` | `string | null` | See omitted-default nuance above |
| `event_id` | `string | null` | Optional |
| `recurring_scope` | enum or `null` | Optional |
| `requires_confirmation` | `boolean` | Always `true` today |
| `warnings` | `string[]` | Derived from preview |
| `before_state` | `object | null` | Preview of touched records before mutation |
| `after_state` | `object | null` | Preview of touched records after mutation |
| `snapshot_hash` | `string` | Hash of current `calendars` + `events` only |
| `created_at` | `string` | UTC ISO timestamp |
| `executed_at` | `string | null` | `null` until execute succeeds |
| `error_message` | `string | null` | Set when proposal becomes stale |

#### Warning generation

Warnings are preview-based and currently occur in these cases:

- Every `delete_event` proposal: `"This operation is destructive and requires explicit confirmation."`
- Every `delete_calendar` proposal: the same destructive warning
- Any proposal whose previewed calendar state contains conflicts: `"Preview contains N timing conflict warning(s)."`
- `delete_calendar` when that calendar contains events: `"Deleting this calendar also removes N event(s)."`

### `GET /api/v1/calendar-operations`

Returns `CalendarOperationListResponse`.

Behavior:

- response shape is `{ owner, feature, uses_mock, operations }`
- `operations` are sorted newest-first by `created_at`
- returned proposal objects omit the internal `request_payload`

### `GET /api/v1/calendar-operations/{proposal_id}`

Returns one `CalendarOperationProposal`.

#### Failure modes

- `404 proposal_not_found`

### `POST /api/v1/calendar-operations/{proposal_id}/execute`

Executes a previously created proposal. Returns `CalendarOperationResult`.

#### Request body

`CalendarOperationExecuteRequest`

| Field | Type | Default / behavior |
|---|---|---|
| `proposal_id` | `string` | Required; must match the path parameter |
| `snapshot_hash` | `string` | Required; must match the proposal snapshot hash |
| `confirmed` | `boolean` | Defaults to `true`, but runtime requires it to be `true` |

#### Success response

`CalendarOperationResult`

| Field | Type |
|---|---|
| `proposal_id` | `string` |
| `operation_type` | enum |
| `status` | enum; `executed` on success |
| `target_summary` | `string` |
| `snapshot_hash` | `string` |
| `executed_at` | `string` |

#### Execution guards

- `confirmed=false` -> `422 confirmation_required`
- body `proposal_id` different from path `proposal_id` -> `409 proposal_mismatch`
- proposal already not `proposed` -> `409 proposal_not_executable`
- supplied `snapshot_hash` different from proposal snapshot -> `409 snapshot_mismatch`
- schedule changed since proposal creation -> `409 proposal_stale`, proposal becomes `stale`, audit record is appended

### `GET /api/v1/calendar-operation-audit`

Returns `CalendarAuditResponse`.

#### Response model

| Field | Type | Notes |
|---|---|---|
| `records` | `CalendarAuditRecord[]` | Newest-first by `recorded_at` |

`CalendarAuditRecord` fields:

| Field | Type |
|---|---|
| `audit_id` | `string` |
| `proposal_id` | `string` |
| `operation_type` | enum |
| `actor` | `string` |
| `calendar_id` | `string | null` |
| `event_id` | `string | null` |
| `recurring_scope` | enum or `null` |
| `warnings` | `string[]` |
| `before_state` | `object | null` |
| `after_state` | `object | null` |
| `result_status` | enum |
| `error_message` | `string | null` |
| `recorded_at` | `string` |

Audit behavior:

- audit entries are written for `executed` proposals
- audit entries are also written when execution detects a stale proposal
- proposal creation alone does not write audit entries
- validation failures before proposal creation or before execution do not write audit entries

## Calendar Operation Enums

### `CalendarOperationType`

- `create_event`
- `update_event`
- `move_event`
- `delete_event`
- `create_calendar`
- `delete_calendar`

### `RecurringEditScope`

- `occurrence`
- `following`
- `series`

### `CalendarOperationStatus`

- `proposed`
- `executed`
- `rejected`
- `stale`
- `failed`

Note: `rejected` and `failed` are present in the schema today, but the current service implementation does not transition proposals into those states.

## Failure Matrix

| Route / scenario | Status | Error code |
|---|---|---|
| Unknown calendar | `404` | `calendar_not_found` |
| Unknown event | `404` | `event_not_found` |
| Unknown proposal | `404` | `proposal_not_found` |
| `date` mixed with `start_date` / `end_date` | `422` | `invalid_query` |
| Missing one side of `start_date` / `end_date` | `422` | `invalid_query` |
| `end_date < start_date` | `422` | `invalid_query` |
| Invalid date string | `422` | `invalid_date` |
| Invalid event datetime string | `422` | `invalid_datetime` |
| Event `end <= start` | `422` | `invalid_time_range` |
| Missing required event payload fields on create | `422` | `invalid_event_payload` |
| Empty event payload on update / move | `422` | `invalid_event_payload` |
| Recurring operation without scope | `422` | `recurring_scope_required` |
| `confirmed=false` on execute | `422` | `confirmation_required` |
| Body/path proposal id mismatch | `409` | `proposal_mismatch` |
| Snapshot hash mismatch with proposal | `409` | `snapshot_mismatch` |
| Proposal already executed or stale | `409` | `proposal_not_executable` |
| Schedule changed after proposal creation | `409` | `proposal_stale` |
| Delete primary calendar in mock mode | `409` | `primary_calendar_protected` |

## Environment Variables That Affect Calendar Behavior

| Variable | Effect |
|---|---|
| `JARVIS_DEFAULT_DATE` | Fallback day for read endpoints with no query |
| `JARVIS_DEFAULT_TIMEZONE` | Seed calendar timezone and default calendar timezone |
| `JARVIS_CALENDAR_STATE_PATH` | File path for mock-backed state persistence |
| `JARVIS_CALENDAR_PROVIDER` | Present in settings; current implementation still uses the mock provider |

Default state path when unset: `Path(tempfile.gettempdir()) / "jarvis-calendar-state.json"`

## Current Non-Goals

- No auth or rate limiting
- No natural-language mutation endpoint
- No Google Calendar integration
- No ICS-grade recurrence engine
- No dedicated frontend calendar management UI
