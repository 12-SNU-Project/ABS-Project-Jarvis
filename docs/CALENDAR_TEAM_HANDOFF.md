# Calendar Team Handoff

This handoff is for the shipped calendar feature on branch `feature/calendar`. It is intentionally operational: it tells the next worker what exists today, what is pinned by tests, what is still mock-backed, and where the remaining gaps are.

## What Is Shipped Today

- Versioned calendar routes under `/api/v1`
- Deterministic read endpoints for calendars, events, conflicts, and summaries
- Briefing integration that embeds calendar summaries in `POST /api/v1/briefings`
- Proposal-first managed-write endpoints for event and calendar mutations
- File-backed mock persistence with isolated test state
- Audit logging for executed and stale proposals
- Generated OpenAPI contract at `/openapi.json`
- Calendar API regression coverage in `backend/tests/test_calendar_api.py`
- OpenAPI contract regression coverage in `backend/tests/test_openapi_contract.py`

## Files To Read First

### API and runtime

- `backend/app/api/endpoints.py`
- `backend/app/services/calendar.py`
- `backend/app/providers/calendar_provider.py`
- `backend/app/schemas/schemas.py`
- `backend/main.py`

### Documentation

- `docs/CALENDAR_API.md`
- `docs/CALENDAR_ARCHITECTURE.md`
- `docs/CALENDAR_TEAM_HANDOFF.md`

### Tests

- `backend/tests/conftest.py`
- `backend/tests/test_calendar_api.py`
- `backend/tests/test_openapi_contract.py`

## Invariants You Should Assume Are Intentional

### Read path

- the read surface is deterministic and does not invoke an LLM
- date queries are strict: either `date` or `start_date` plus `end_date`
- no-query reads fall back to `JARVIS_DEFAULT_DATE`
- event filtering is overlap-based, not start-time-only
- conflict detection only emits `overlap` and `tight_buffer`
- `/events` does not expose the service's internal `range_label`

### Write path

- proposal creation never mutates the schedule
- execution requires `confirmed=true`
- execution requires the exact `snapshot_hash`
- stale proposals are rejected and audited
- recurring mutations never infer scope
- delete operations always emit a destructive warning

### Mock persistence

- state lives at `JARVIS_CALENDAR_STATE_PATH`
- default state is created on first load
- the primary calendar cannot be deleted in mock mode
- proposal ordering is newest-first by `created_at`
- audit ordering is newest-first by `recorded_at`

## Known Contract Gaps

These are real gaps in the shipped contract, not documentation omissions:

1. OpenAPI does not encode several runtime validation rules.
   It does not express operation-specific requirements like `create_event` needing `title/start/end`, or recurring operations requiring recurrence metadata.

2. `CalendarOperationProposalRequest.calendar_id` has an OpenAPI default of `"primary"`, but omitted values are not always echoed back in stored proposals because the route uses `exclude_unset=True`.

3. `move_event` is not a distinct mutation shape.
   It shares the same payload and runtime path as `update_event`.

4. Enum values `rejected` and `failed` exist in the schema, but current service code does not transition proposals into those states.

## Functional Gaps Still Outside This Worker's Scope

- Real Google Calendar provider behind the existing provider boundary
- Auth and authorization for write routes
- Rate limiting and abuse controls
- Frontend proposal-review UI
- Natural-language to structured mutation translation
- Richer recurrence semantics beyond the current concrete-event series model

## Verification Workflow

Run from `backend/`:

```bash
uv run pytest tests/test_calendar_api.py tests/test_openapi_contract.py
```

Optional broader pass:

```bash
uv run pytest tests
```

## Safe Extension Guidance

- If you change route names, request/response model names, or enum values, update both calendar API tests and the OpenAPI contract test.
- If you change runtime validation rules, update `docs/CALENDAR_API.md`; OpenAPI may not reflect those rules automatically.
- If you introduce a real provider, preserve the proposal/execute and audit contracts in the service layer.
- If you add auth, document whether the briefing route and read routes remain internal-only or become client-facing.
