from __future__ import annotations

import json
import re
from datetime import datetime
from typing import Any
from urllib import error as urllib_error
from urllib import request as urllib_request
from zoneinfo import ZoneInfo

from app.core.config import get_settings
from app.core.errors import AppError
from app.schemas.schemas import AgentInterpretResponse, AgentInterpretStatus
from app.services.calendar_read import get_calendar_events_response


AGENT_OWNER = "agent"
AGENT_FEATURE = "agent_interpreter"
OPENAI_RESPONSES_URL = "https://api.openai.com/v1/responses"


def _extract_output_text(payload: dict[str, Any]) -> str:
    output_text = payload.get("output_text")
    if isinstance(output_text, str) and output_text.strip():
        return output_text.strip()

    collected: list[str] = []

    for item in payload.get("output", []):
        if item.get("type") != "message":
            continue
        for content in item.get("content", []):
            if content.get("type") == "output_text" and content.get("text"):
                collected.append(content["text"])

    return "".join(collected).strip()


def _post_openai_responses(body: dict[str, Any], *, api_key: str) -> dict[str, Any]:
    data = json.dumps(body).encode("utf-8")
    req = urllib_request.Request(
        OPENAI_RESPONSES_URL,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )

    try:
        with urllib_request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib_error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        message = "OpenAI request failed."
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = None

        if isinstance(payload, dict):
            api_error = payload.get("error")
            if isinstance(api_error, dict) and api_error.get("message"):
                message = str(api_error["message"])
        elif raw:
            message = raw

        raise AppError(
            code="openai_request_failed",
            message=message,
            status_code=502,
        ) from exc
    except urllib_error.URLError as exc:
        raise AppError(
            code="openai_unreachable",
            message="Could not reach the OpenAI API.",
            status_code=502,
        ) from exc


def _build_system_prompt(
    *,
    selected_date: str,
    calendar_id: str,
    latest_proposal_id: str | None,
    events: list[dict[str, Any]],
) -> str:
    event_context = json.dumps(events, ensure_ascii=False, separators=(",", ":"))
    latest_proposal = latest_proposal_id or "none"
    return f"""
You are a calendar command interpreter for a UI agent.
Convert the user's request into JSON for a downstream parser.
You can only work with the available backend APIs. If a request is out of scope,
do not hallucinate execution.

Return JSON with exactly these keys:
- status: "interpreted" or "clarify"
- command: string or null
- explanation: string

Use only the supported command grammar below when status is "interpreted":
- help
- refresh
- show calendars
- inspect calendar <calendar_id>
- show schedule for <YYYY-MM-DD> calendar <calendar_id>
- show conflicts for <YYYY-MM-DD> calendar <calendar_id>
- show summary for <YYYY-MM-DD> calendar <calendar_id>
- show proposals
- show proposal <proposal_id>
- show audit
- show briefing for <YYYY-MM-DD>
- create calendar "<name>" timezone <IANA timezone>
- delete calendar <calendar_id>
- create event "<title>" on <YYYY-MM-DD> from <HH:MM> to <HH:MM> [at "<location>"] [priority high|medium|low] [calendar <id>]
- update event <event_id> title "<title>" [location "<location>"] [priority high|medium|low] [calendar <id>]
- move event <event_id> to <YYYY-MM-DD> from <HH:MM> to <HH:MM> [scope occurrence|following|series] [calendar <id>]
- delete event <event_id> [scope occurrence|following|series] [calendar <id>]
- execute <proposal_id|latest>
- reject <proposal_id|latest>
- show slack summary channel <channel_id> lookback <hours>
- show slack activity channel <channel_id> lookback <hours>
- show admin summary
- show health sleep summary

Rules:
- Always return valid JSON.
- Use the provided event list to resolve event names to event IDs.
- Match event titles leniently, including spacing differences and Korean text variants.
- If the user asks to defer, delay, postpone, or move an event later by a duration, preserve the original duration and shift both start and end.
- If the user asks to bring an event forward or earlier by a duration, preserve the original duration and shift both start and end earlier.
- Default to the selected date {selected_date} and calendar {calendar_id} unless the user explicitly changes them.
- When referring to the latest proposal, use "execute latest" unless a specific proposal id is requested.
- Never output calendar mutations as executed results. Always output the command to draft or execute, not the outcome.
- If the request is outside supported tools (e.g., browser automation, filesystem edits, OS control, email sending), return:
  status "clarify", command null, and explanation that starts with "Unsupported:" followed by what the user can request instead.
- If the request is ambiguous, missing a target event, or cannot be mapped safely, return status "clarify", command null, and explain what is missing.

Context:
- selected_date: {selected_date}
- selected_calendar_id: {calendar_id}
- latest_proposal_id: {latest_proposal}
- events: {event_context}
""".strip()


def _normalize_hhmm(text: str) -> str:
    def _replace(match: re.Match[str]) -> str:
        hour = int(match.group(1))
        minute = int(match.group(2))
        if hour < 0 or hour > 23 or minute < 0 or minute > 59:
            return match.group(0)
        return f"{hour:02d}:{minute:02d}"

    return re.sub(r"\b(\d{1,2})\s*:\s*(\d{1,2})\b", _replace, text)


def _normalize_korean_time(text: str) -> str:
    pattern = re.compile(
        r"(오전|오후)?\s*(\d{1,2})\s*시(?:\s*(반)|\s*(\d{1,2})\s*분?)?"
    )

    def _replace(match: re.Match[str]) -> str:
        meridiem = (match.group(1) or "").strip()
        hour = int(match.group(2))
        half = match.group(3)
        minute_raw = match.group(4)

        minute = 30 if half else int(minute_raw) if minute_raw else 0
        if minute < 0 or minute > 59 or hour < 0 or hour > 23:
            return match.group(0)

        if meridiem == "오전":
            if hour == 12:
                hour = 0
        elif meridiem == "오후":
            if hour < 12:
                hour += 12
        return f"{hour:02d}:{minute:02d}"

    return pattern.sub(_replace, text)


def _normalize_user_input(user_input: str) -> str:
    normalized = user_input.replace("\n", " ").replace("\t", " ")
    normalized = re.sub(r"\s+", " ", normalized).strip()
    normalized = _normalize_hhmm(normalized)
    normalized = _normalize_korean_time(normalized)

    replacements = {
        "자비쓰": "자비스",
        "재비스": "자비스",
        "케린더": "캘린더",
        "켈린더": "캘린더",
        "캘랜더": "캘린더",
        "스랙": "슬랙",
        "스렉": "슬랙",
        "슬렉": "슬랙",
    }
    for source, target in replacements.items():
        normalized = normalized.replace(source, target)

    return normalized


def _build_user_prompt(*, raw_input: str, normalized_input: str) -> str:
    return (
        "Resolve the request using the normalized input first, while preserving user intent.\n"
        "If raw and normalized differ, treat normalized text as STT-corrected form unless it is clearly invalid.\n"
        f"Raw input: {raw_input}\n"
        f"Normalized input: {normalized_input}"
    )


def _iso_in_default_timezone(date_value: str, hhmm: str) -> str:
    tz = ZoneInfo(get_settings().default_timezone)
    parsed = datetime.fromisoformat(f"{date_value}T{hhmm}:00")
    return parsed.replace(tzinfo=tz).isoformat()


def _proposal_tool_call(body: dict[str, Any]) -> dict[str, Any]:
    return {
        "name": "create_calendar_operation_proposal",
        "method": "POST",
        "path": "/api/v1/calendar-operations/proposals",
        "query": {},
        "body": body,
    }


def _build_tool_calls_from_command(
    *,
    command: str,
    selected_date: str,
    default_calendar_id: str,
    latest_proposal_id: str | None,
) -> tuple[list[dict[str, Any]], str | None]:
    line = command.strip()
    if not line:
        return [], "Empty command."

    if line in {"help", "refresh"}:
        return [
            {
                "name": "health_check",
                "method": "GET",
                "path": "/api/v1/health",
                "query": {},
                "body": None,
            }
        ], None

    if line == "show calendars":
        return [
            {
                "name": "list_calendars",
                "method": "GET",
                "path": "/api/v1/calendars",
                "query": {},
                "body": None,
            }
        ], None

    match = re.fullmatch(r"inspect calendar (\S+)", line)
    if match:
        calendar_id = match.group(1)
        return [
            {
                "name": "get_calendar",
                "method": "GET",
                "path": f"/api/v1/calendars/{calendar_id}",
                "query": {},
                "body": None,
            }
        ], None

    match = re.fullmatch(r"show schedule for (\d{4}-\d{2}-\d{2}) calendar (\S+)", line)
    if match:
        date_value, calendar_id = match.groups()
        return [
            {
                "name": "list_calendar_events",
                "method": "GET",
                "path": f"/api/v1/calendars/{calendar_id}/events",
                "query": {"date": date_value},
                "body": None,
            }
        ], None

    match = re.fullmatch(r"show conflicts for (\d{4}-\d{2}-\d{2}) calendar (\S+)", line)
    if match:
        date_value, calendar_id = match.groups()
        return [
            {
                "name": "list_calendar_conflicts",
                "method": "GET",
                "path": f"/api/v1/calendars/{calendar_id}/conflicts",
                "query": {"date": date_value},
                "body": None,
            }
        ], None

    match = re.fullmatch(r"show summary for (\d{4}-\d{2}-\d{2}) calendar (\S+)", line)
    if match:
        date_value, calendar_id = match.groups()
        return [
            {
                "name": "get_calendar_summary",
                "method": "GET",
                "path": f"/api/v1/calendars/{calendar_id}/summary",
                "query": {"date": date_value},
                "body": None,
            }
        ], None

    if line == "show proposals":
        return [
            {
                "name": "list_calendar_operation_proposals",
                "method": "GET",
                "path": "/api/v1/calendar-operations",
                "query": {},
                "body": None,
            }
        ], None

    match = re.fullmatch(r"show proposal (\S+)", line)
    if match:
        proposal_id = match.group(1)
        return [
            {
                "name": "get_calendar_operation_proposal",
                "method": "GET",
                "path": f"/api/v1/calendar-operations/{proposal_id}",
                "query": {},
                "body": None,
            }
        ], None

    if line == "show audit":
        return [
            {
                "name": "list_calendar_operation_audit_records",
                "method": "GET",
                "path": "/api/v1/calendar-operation-audit",
                "query": {},
                "body": None,
            }
        ], None

    match = re.fullmatch(r"show briefing for (\d{4}-\d{2}-\d{2})", line)
    if match:
        date_value = match.group(1)
        return [
            {
                "name": "create_briefing",
                "method": "POST",
                "path": "/api/v1/briefings",
                "query": {},
                "body": {
                    "user_input": "오늘 상태를 짧게 브리핑해줘.",
                    "location": "Seoul",
                    "date": date_value,
                },
            }
        ], None

    match = re.fullmatch(r'create calendar "(.+)" timezone (\S+)', line)
    if match:
        name, timezone = match.groups()
        return [
            _proposal_tool_call(
                {
                    "operation_type": "create_calendar",
                    "actor": "agent",
                    "calendar": {"name": name, "timezone": timezone},
                }
            )
        ], None

    match = re.fullmatch(r"delete calendar (\S+)", line)
    if match:
        calendar_id = match.group(1)
        return [
            _proposal_tool_call(
                {
                    "operation_type": "delete_calendar",
                    "actor": "agent",
                    "calendar_id": calendar_id,
                }
            )
        ], None

    match = re.fullmatch(
        r'create event "(.+)" on (\d{4}-\d{2}-\d{2}) from (\d{2}:\d{2}) to (\d{2}:\d{2})(?: at "(.+)")?(?: priority (high|medium|low))?(?: calendar (\S+))?',
        line,
    )
    if match:
        (
            title,
            date_value,
            start_time,
            end_time,
            location,
            priority,
            calendar_id,
        ) = match.groups()
        target_calendar = calendar_id or default_calendar_id
        event_payload: dict[str, Any] = {
            "title": title,
            "start": _iso_in_default_timezone(date_value, start_time),
            "end": _iso_in_default_timezone(date_value, end_time),
        }
        if location:
            event_payload["location"] = location
        if priority:
            event_payload["priority"] = priority
        return [
            _proposal_tool_call(
                {
                    "operation_type": "create_event",
                    "actor": "agent",
                    "calendar_id": target_calendar,
                    "event": event_payload,
                }
            )
        ], None

    match = re.fullmatch(
        r'update event (\S+) title "(.+)"(?: location "(.+)")?(?: priority (high|medium|low))?(?: calendar (\S+))?',
        line,
    )
    if match:
        event_id, title, location, priority, calendar_id = match.groups()
        target_calendar = calendar_id or default_calendar_id
        event_payload: dict[str, Any] = {"title": title}
        if location:
            event_payload["location"] = location
        if priority:
            event_payload["priority"] = priority
        return [
            _proposal_tool_call(
                {
                    "operation_type": "update_event",
                    "actor": "agent",
                    "calendar_id": target_calendar,
                    "event_id": event_id,
                    "event": event_payload,
                }
            )
        ], None

    match = re.fullmatch(
        r"move event (\S+) to (\d{4}-\d{2}-\d{2}) from (\d{2}:\d{2}) to (\d{2}:\d{2})(?: scope (occurrence|following|series))?(?: calendar (\S+))?",
        line,
    )
    if match:
        (
            event_id,
            date_value,
            start_time,
            end_time,
            scope,
            calendar_id,
        ) = match.groups()
        target_calendar = calendar_id or default_calendar_id
        body: dict[str, Any] = {
            "operation_type": "move_event",
            "actor": "agent",
            "calendar_id": target_calendar,
            "event_id": event_id,
            "event": {
                "start": _iso_in_default_timezone(date_value, start_time),
                "end": _iso_in_default_timezone(date_value, end_time),
            },
        }
        if scope:
            body["recurring_scope"] = scope
        return [_proposal_tool_call(body)], None

    match = re.fullmatch(
        r"delete event (\S+)(?: scope (occurrence|following|series))?(?: calendar (\S+))?",
        line,
    )
    if match:
        event_id, scope, calendar_id = match.groups()
        target_calendar = calendar_id or default_calendar_id
        body: dict[str, Any] = {
            "operation_type": "delete_event",
            "actor": "agent",
            "calendar_id": target_calendar,
            "event_id": event_id,
        }
        if scope:
            body["recurring_scope"] = scope
        return [_proposal_tool_call(body)], None

    match = re.fullmatch(r"execute (\S+)", line)
    if match:
        requested = match.group(1)
        resolved = latest_proposal_id if requested == "latest" else requested
        if not resolved:
            return [], "No latest proposal exists. Ask for show proposals first."
        return [
            {
                "name": "execute_calendar_operation_proposal",
                "method": "POST",
                "path": f"/api/v1/calendar-operations/{resolved}/execute",
                "query": {},
                "body": {
                    "proposal_id": resolved,
                    "snapshot_hash": "<required-from-proposal>",
                    "confirmed": True,
                },
            }
        ], None

    match = re.fullmatch(r"reject (\S+)", line)
    if match:
        requested = match.group(1)
        resolved = latest_proposal_id if requested == "latest" else requested
        if not resolved:
            return [], "No latest proposal exists. Ask for show proposals first."
        return [
            {
                "name": "reject_calendar_operation_proposal",
                "method": "POST",
                "path": f"/api/v1/calendar-operations/{resolved}/reject",
                "query": {},
                "body": {
                    "proposal_id": resolved,
                    "reason": "Rejected by agent workflow.",
                },
            }
        ], None

    match = re.fullmatch(r"show slack summary channel (\S+) lookback (\d+)", line)
    if match:
        channel_id, lookback = match.groups()
        return [
            {
                "name": "slack_summary",
                "method": "POST",
                "path": "/api/v1/slack/summary",
                "query": {},
                "body": {
                    "channel_id": channel_id,
                    "user_input": "최근 대화 핵심 요약",
                    "date": selected_date,
                    "lookback_hours": int(lookback),
                },
            }
        ], None

    match = re.fullmatch(r"show slack activity channel (\S+) lookback (\d+)", line)
    if match:
        channel_id, lookback = match.groups()
        return [
            {
                "name": "slack_activity",
                "method": "GET",
                "path": "/api/v1/slack/activity",
                "query": {
                    "channel_id": channel_id,
                    "lookback_hours": int(lookback),
                    "date": selected_date,
                },
                "body": None,
            }
        ], None

    if line == "show admin summary":
        return [
            {
                "name": "admin_summary",
                "method": "GET",
                "path": "/api/v1/admin/summary",
                "query": {},
                "body": None,
            }
        ], None

    if line == "show health sleep summary":
        return [
            {
                "name": "health_sleep_summary",
                "method": "GET",
                "path": "/api/v1/health/sleep",
                "query": {},
                "body": None,
            }
        ], None

    return [], f"Unsupported normalized command: '{line}'."


def interpret_agent_instruction(
    *,
    user_input: str,
    date: str,
    calendar_id: str,
    latest_proposal_id: str | None = None,
) -> AgentInterpretResponse:
    settings = get_settings()
    if not settings.openai_api_key:
        raise AppError(
            code="openai_not_configured",
            message="OPENAI_API_KEY is not configured for the backend agent interpreter.",
            status_code=503,
        )

    events_response = get_calendar_events_response(calendar_id, date_value=date)
    events = [
        {
            "id": event["id"],
            "title": event["title"],
            "start": event["start"],
            "end": event["end"],
            "location": event.get("location"),
            "priority": event.get("priority"),
            "recurring": event.get("recurring", False),
            "series_id": event.get("series_id"),
        }
        for event in events_response["events"]
    ]

    normalized_input = _normalize_user_input(user_input)

    payload = {
        "model": settings.openai_model,
        "input": [
            {
                "role": "system",
                "content": _build_system_prompt(
                    selected_date=date,
                    calendar_id=calendar_id,
                    latest_proposal_id=latest_proposal_id,
                    events=events,
                ),
            },
            {
                "role": "user",
                "content": _build_user_prompt(
                    raw_input=user_input,
                    normalized_input=normalized_input,
                ),
            },
        ],
        "text": {"format": {"type": "json_object"}},
    }
    response_payload = _post_openai_responses(payload, api_key=settings.openai_api_key)
    output_text = _extract_output_text(response_payload)
    if not output_text:
        raise AppError(
            code="openai_empty_response",
            message="OpenAI returned an empty command interpretation.",
            status_code=502,
        )

    try:
        parsed = json.loads(output_text)
    except json.JSONDecodeError as exc:
        raise AppError(
            code="openai_invalid_response",
            message="OpenAI returned invalid JSON for the command interpretation.",
            status_code=502,
        ) from exc

    status = parsed.get("status")
    explanation = str(parsed.get("explanation", "")).strip()
    command = parsed.get("command")

    if status not in {
        AgentInterpretStatus.INTERPRETED.value,
        AgentInterpretStatus.CLARIFY.value,
    }:
        raise AppError(
            code="openai_invalid_response",
            message="OpenAI returned an unsupported interpretation status.",
            status_code=502,
        )

    if status == AgentInterpretStatus.INTERPRETED.value:
        if not isinstance(command, str) or not command.strip():
            raise AppError(
                code="openai_invalid_response",
                message="OpenAI did not provide a normalized command.",
                status_code=502,
            )
        command = command.strip()
        tool_calls, tool_error = _build_tool_calls_from_command(
            command=command,
            selected_date=date,
            default_calendar_id=calendar_id,
            latest_proposal_id=latest_proposal_id,
        )
        if tool_error:
            status = AgentInterpretStatus.CLARIFY.value
            command = None
            prefix = "Unsupported:" if "Unsupported" in tool_error else "Clarify:"
            explanation = f"{prefix} {tool_error}"
            tool_calls = []
    else:
        command = None
        tool_calls = []

    return AgentInterpretResponse(
        owner=AGENT_OWNER,
        feature=AGENT_FEATURE,
        uses_mock=settings.use_mocks,
        status=AgentInterpretStatus(status),
        source="openai",
        command=command,
        explanation=explanation or "The instruction requires clarification.",
        tool_calls=tool_calls,
    )
