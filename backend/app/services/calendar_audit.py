from __future__ import annotations

import uuid
from typing import Any

from app.core.errors import AppError, error_detail
from app.providers.calendar_provider import (
    append_audit_record,
    get_proposal,
    list_audit_records,
    list_proposals,
    load_calendar_state,
    replace_proposal,
    save_calendar_state,
)
from app.services.calendar_read import (
    base_calendar_payload,
    current_timestamp,
    schedule_snapshot_hash,
)
from app.services.calendar_write import apply_operation


def proposal_view(proposal: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in proposal.items() if key != "request_payload"}


def execution_result(proposal: dict[str, Any]) -> dict[str, Any]:
    return {
        "proposal_id": proposal["proposal_id"],
        "operation_type": proposal["operation_type"],
        "status": proposal["status"],
        "target_summary": proposal["target_summary"],
        "snapshot_hash": proposal["snapshot_hash"],
        "executed_at": proposal["executed_at"],
    }


def build_audit_record(
    proposal: dict[str, Any],
    *,
    before_state: dict[str, Any] | None,
    after_state: dict[str, Any] | None,
    result_status: str,
    error_message: str | None,
    recorded_at: str,
) -> dict[str, Any]:
    return {
        "audit_id": f"audit-{uuid.uuid4().hex[:12]}",
        "proposal_id": proposal["proposal_id"],
        "operation_type": proposal["operation_type"],
        "actor": proposal["actor"],
        "calendar_id": proposal.get("calendar_id"),
        "event_id": proposal.get("event_id"),
        "recurring_scope": proposal.get("recurring_scope"),
        "warnings": proposal["warnings"],
        "before_state": before_state,
        "after_state": after_state,
        "result_status": result_status,
        "error_message": error_message,
        "recorded_at": recorded_at,
    }


def list_calendar_operation_proposals() -> dict[str, Any]:
    state = load_calendar_state()
    operations = [proposal_view(proposal) for proposal in list_proposals(state)]
    return {**base_calendar_payload(), "operations": operations}


def get_calendar_operation_proposal(proposal_id: str) -> dict[str, Any]:
    state = load_calendar_state()
    proposal = get_proposal(state, proposal_id)
    return proposal_view(proposal)


def execute_calendar_operation(proposal_id: str, snapshot_hash: str, confirmed: bool) -> dict[str, Any]:
    if not confirmed:
        raise AppError(
            code="confirmation_required",
            message="confirmed must be true to execute an operation.",
            status_code=422,
            details=[
                error_detail(
                    code="confirmation_required",
                    message="confirmed must be true to execute an operation.",
                    field="confirmed",
                )
            ],
        )

    state = load_calendar_state()
    proposal = get_proposal(state, proposal_id)

    if proposal["snapshot_hash"] != snapshot_hash:
        raise AppError(
            code="snapshot_mismatch",
            message="The supplied snapshot hash does not match the proposal.",
            status_code=409,
        )

    if proposal["status"] == "executed":
        return execution_result(proposal)

    if proposal["status"] != "proposed":
        raise AppError(
            code="proposal_not_executable",
            message=f"Proposal '{proposal_id}' is already in status '{proposal['status']}'.",
            status_code=409,
        )

    if schedule_snapshot_hash(state) != proposal["snapshot_hash"]:
        error_message = "Calendar state changed after this proposal was created."
        proposal["status"] = "stale"
        proposal["error_message"] = error_message
        replace_proposal(state, proposal_id, proposal)
        append_audit_record(
            state,
            build_audit_record(
                proposal,
                before_state=proposal.get("before_state"),
                after_state=proposal.get("after_state"),
                result_status="stale",
                error_message=error_message,
                recorded_at=current_timestamp(),
            ),
        )
        save_calendar_state(state)
        raise AppError(code="proposal_stale", message=error_message, status_code=409)

    before_state, after_state = apply_operation(state, proposal["request_payload"])
    executed_at = current_timestamp()
    proposal["status"] = "executed"
    proposal["before_state"] = before_state
    proposal["after_state"] = after_state
    proposal["executed_at"] = executed_at
    replace_proposal(state, proposal_id, proposal)
    append_audit_record(
        state,
        build_audit_record(
            proposal,
            before_state=before_state,
            after_state=after_state,
            result_status="executed",
            error_message=None,
            recorded_at=executed_at,
        ),
    )
    save_calendar_state(state)
    return execution_result(proposal)


def get_calendar_audit_log() -> dict[str, Any]:
    state = load_calendar_state()
    return {**base_calendar_payload(), "records": list_audit_records(state)}
