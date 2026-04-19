# Calendar Architecture

This document describes the shipped calendar architecture on `feature/calendar`. It is intentionally implementation-specific: it reflects the current FastAPI routes, the mock-backed provider, the proposal/execute mutation flow, and the deterministic summary logic that feeds Jarvis briefings.

## Responsibilities

The calendar feature currently serves two separate consumers:

1. The Jarvis briefing pipeline, which needs a deterministic calendar summary for a given day.
2. Agent or internal clients that need a safe write path for schedule mutations without allowing immediate state changes.

Those concerns share the same provider-backed state but use different contracts:

- read routes and briefing integration are pure reads
- write routes are proposal-first and hash-guarded

## High-Level Shape

```text
POST /api/v1/briefings
        |
        v
  orchestrator.create_briefing(...)
        |
        +--> weather service
        +--> calendar.get_calendar_brief(date, "primary")
        +--> slack service
        +--> admin service
        +--> presentation service
```

```text
GET /api/v1/calendars/...            POST/GET /api/v1/calendar-operations/...
              |                                           |
              v                                           v
      calendar service                            calendar service
              |                                           |
              +---------------------+---------------------+
                                    |
                                    v
                      app.providers.calendar_provider
                                    |
                                    v
                     file-backed JSON state on local disk
```

## API Surface Owned By The Calendar Feature

### Read surface

- `GET /api/v1/calendars`
- `GET /api/v1/calendars/{calendar_id}`
- `GET /api/v1/calendars/{calendar_id}/events`
- `GET /api/v1/calendars/{calendar_id}/conflicts`
- `GET /api/v1/calendars/{calendar_id}/summary`

### Write surface

- `POST /api/v1/calendar-operations/proposals`
- `GET /api/v1/calendar-operations`
- `GET /api/v1/calendar-operations/{proposal_id}`
- `POST /api/v1/calendar-operations/{proposal_id}/execute`
- `GET /api/v1/calendar-operation-audit`

### Embedded consumer

- `POST /api/v1/briefings` consumes the calendar feature through `get_calendar_brief`

## Layer Responsibilities

### `backend/app/api/endpoints.py`

- exposes versioned HTTP routes
- binds route inputs to Pydantic models and query/path params
- strips the internal `range_label` from the `/events` response before serialization
- enforces the execute body/path `proposal_id` match before delegating to the service

### `backend/app/services/calendar.py`

- resolves read windows from `date` or `start_date`/`end_date`
- enforces runtime validation that OpenAPI does not fully encode
- computes deterministic conflict detection and summary strings
- previews write operations on cloned state before proposal creation
- creates and persists proposals with snapshot hashes
- executes proposals only after confirmation and hash validation
- appends audit records for executed and stale operations

### `backend/app/providers/calendar_provider.py`

- persists state to a local JSON file
- normalizes legacy or partial event fields on load/save
- seeds default calendars and events if no state file exists
- implements concrete event/calendar CRUD against the JSON state
- enforces recurring-scope behavior at the provider layer

## State Model

The persisted state file contains exactly four top-level collections:

- `calendars`
- `events`
- `proposals`
- `audit_records`

Only `calendars` and `events` contribute to the schedule snapshot hash. Proposal persistence itself does not invalidate the proposal hash.

## Persistence And Seeding

### State path

- env var: `JARVIS_CALENDAR_STATE_PATH`
- default: `Path(tempfile.gettempdir()) / "jarvis-calendar-state.json"`

### Seed behavior

If the state file does not exist, the provider creates:

- one primary calendar
- seed events derived from `backend/app/data/mocks/calendar.json`
- one recurring series named `Team Sync` with three weekly occurrences
- empty `proposals`
- empty `audit_records`

### Time defaults

- `JARVIS_DEFAULT_DATE` determines the seed date and the default read date
- `JARVIS_DEFAULT_TIMEZONE` determines the primary calendar timezone and seed event offsets

In tests, those values are intentionally pinned to:

- `2026-04-18`
- `Asia/Seoul`

## Read Path Details

### Window resolution

The service accepts either:

- a single `date`
- or `start_date` plus `end_date`

If neither is supplied, it falls back to the configured default date.

Range windows are inclusive by day because the service converts:

- `start_date` -> `YYYY-MM-DDT00:00:00+09:00`
- `end_date` -> next midnight after the supplied end day

### Event selection

The provider includes any event that overlaps the window:

- `event.end > window_start`
- `event.start < window_end`

That means long-running events spanning midnight still appear if they overlap the queried date range.

### Conflict detection

Conflict detection is deterministic and uses adjacent events sorted by start time.

Rules:

- `overlap`: current event starts before previous event ends
- `tight_buffer`: less than 30 minutes between previous end and current start

Conflict severity:

- `high` for overlap
- `medium` for tight buffer

### Summary generation

The summary string is built from:

- total event count
- count of `priority == "high"`
- count of detected conflicts

If there are no events, the service returns `No scheduled events found for {label}.`

## Write Path Details

### Proposal-first contract

The write path is deliberately two-step:

1. proposal creation previews the change but does not mutate persisted schedule state
2. execution performs the mutation only if the proposal is still valid

### Proposal preview

Previewing is done against a cloned copy of the current state. The service captures:

- `before_state`
- `after_state`
- `warnings`
- `snapshot_hash`

Warnings are policy-level signals, not hard blocks.

### Snapshot hashing

The schedule hash is a SHA-256 over a normalized JSON payload containing only:

- `calendars`
- `events`

This is what allows proposals to coexist without their own storage changing the hash they depend on.

### Execution guards

Execution is blocked when:

- `confirmed` is `false`
- the request body `proposal_id` does not match the path parameter
- the supplied `snapshot_hash` does not match the stored proposal hash
- the proposal is no longer in `proposed` status
- the live schedule hash has changed since proposal creation

### Audit behavior

Audit records are appended when:

- a proposal executes successfully
- a proposal is detected as stale during execution

Audit records are not created for:

- proposal creation
- validation failures before proposal creation
- execute requests rejected before the stale check

## Recurring Event Model

Recurring behavior is intentionally narrow and deterministic.

Current shipped model:

- recurring series are represented as multiple concrete event rows
- linked by `series_id`
- recurrence metadata is echoed on each event row

Supported edit scopes:

- `occurrence`
- `following`
- `series`

Provider behavior:

- non-recurring targets ignore `recurring_scope`
- recurring targets require explicit scope
- `following` applies to the targeted occurrence and every later occurrence in the same series

This is not a general-purpose recurrence engine. It does not parse or maintain full ICS semantics beyond the fields stored on each event.

## Generated OpenAPI vs Runtime Behavior

The OpenAPI schema accurately captures:

- path surface
- success response models
- enum values
- request body component names
- path/query parameter names and descriptions

The OpenAPI schema does not currently encode several runtime invariants enforced below the route layer:

- `create_event` requiring `event.title`, `event.start`, and `event.end`
- `update_event` / `move_event` requiring a non-empty event payload
- recurring create/update requiring `recurrence_count` and `recurrence_interval_days` when `recurring=true`
- custom application error envelopes for `404`, `409`, and service-level `422` failures

That mismatch matters for SDK generation and external clients, but it does not affect the runtime behavior described in `docs/CALENDAR_API.md`.

## Constraints And Deliberate Omissions

- No auth or authorization
- No rate limiting
- No Google Calendar integration
- No external datastore; persistence is file-backed
- No natural-language write endpoint
- No UI for reviewing proposals outside direct API consumers
- No status transitions into `rejected` or `failed` in the current service implementation, even though those enum values exist
