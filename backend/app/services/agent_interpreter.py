from __future__ import annotations

import json
from typing import Any
from urllib import error as urllib_error
from urllib import request as urllib_request

from app.core.config import get_settings
from app.core.errors import AppError
from app.schemas.schemas import AgentInterpretResponse, AgentInterpretStatus
from app.services.calendar_read import get_calendar_events_response


AGENT_OWNER = "agent"
AGENT_FEATURE = "agent_interpreter"
OPENROUTER_RESPONSES_URL = "https://openrouter.ai/api/v1/responses"


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


def _post_openrouter_responses(
    body: dict[str, Any],
    *,
    api_key: str,
    site_url: str,
    site_name: str,
) -> dict[str, Any]:
    data = json.dumps(body).encode("utf-8")
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    if site_url:
        headers["HTTP-Referer"] = site_url
    if site_name:
        headers["X-OpenRouter-Title"] = site_name
    req = urllib_request.Request(
        OPENROUTER_RESPONSES_URL,
        data=data,
        method="POST",
        headers=headers,
    )

    try:
        with urllib_request.urlopen(req, timeout=30) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib_error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        message = "OpenRouter request failed."
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
            message="Could not reach the OpenRouter API.",
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

Rules:
- Always return valid JSON.
- Use the provided event list to resolve event names to event IDs.
- Match event titles leniently, including spacing differences and Korean text variants.
- If the user asks to defer, delay, postpone, or move an event later by a duration, preserve the original duration and shift both start and end.
- If the user asks to bring an event forward or earlier by a duration, preserve the original duration and shift both start and end earlier.
- Default to the selected date {selected_date} and calendar {calendar_id} unless the user explicitly changes them.
- When referring to the latest proposal, use "execute latest" unless a specific proposal id is requested.
- Never output calendar mutations as executed results. Always output the command to draft or execute, not the outcome.
- If the request is ambiguous, missing a target event, or cannot be mapped safely, return status "clarify", command null, and explain what is missing.

Context:
- selected_date: {selected_date}
- selected_calendar_id: {calendar_id}
- latest_proposal_id: {latest_proposal}
- events: {event_context}
""".strip()


def interpret_agent_instruction(
    *,
    user_input: str,
    date: str,
    calendar_id: str,
    latest_proposal_id: str | None = None,
) -> AgentInterpretResponse:
    settings = get_settings()
    if not settings.openrouter_api_key:
        raise AppError(
            code="openai_not_configured",
            message="OPENROUTER_API_KEY is not configured for the backend agent interpreter.",
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

    payload = {
        "model": settings.openrouter_model,
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
            {"role": "user", "content": user_input},
        ],
        "text": {"format": {"type": "json_object"}},
    }
    response_payload = _post_openrouter_responses(
        payload,
        api_key=settings.openrouter_api_key,
        site_url=settings.openrouter_site_url,
        site_name=settings.openrouter_site_name,
    )
    output_text = _extract_output_text(response_payload)
    if not output_text:
        raise AppError(
            code="openai_empty_response",
            message="OpenRouter returned an empty command interpretation.",
            status_code=502,
        )

    try:
        parsed = json.loads(output_text)
    except json.JSONDecodeError as exc:
        raise AppError(
            code="openai_invalid_response",
            message="OpenRouter returned invalid JSON for the command interpretation.",
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
            message="OpenRouter returned an unsupported interpretation status.",
            status_code=502,
        )

    if status == AgentInterpretStatus.INTERPRETED.value:
        if not isinstance(command, str) or not command.strip():
            raise AppError(
                code="openai_invalid_response",
                message="OpenRouter did not provide a normalized command.",
                status_code=502,
            )
        command = command.strip()
    else:
        command = None

    return AgentInterpretResponse(
        owner=AGENT_OWNER,
        feature=AGENT_FEATURE,
        uses_mock=settings.use_mocks,
        status=AgentInterpretStatus(status),
        source="openrouter",
        command=command,
        explanation=explanation or "The instruction requires clarification.",
    )
