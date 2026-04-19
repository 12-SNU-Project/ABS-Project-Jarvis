from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
import json
from typing import Any

from app.core.config import get_settings
from app.schemas.schemas import (
    AssistantServiceStatus,
    StartupGreetingResponse,
)

from .interpreter import _extract_output_text, _post_openai_responses
from ..calendar import get_calendar_brief
from ..integrations.slack_summary import summarize_slack_channel
from ..integrations.weather import get_weather_brief


STARTUP_GREETING_OWNER = "assistant"
STARTUP_GREETING_FEATURE = "startup_greeting"


def _status(service: str, status: str, message: str) -> AssistantServiceStatus:
    return AssistantServiceStatus(service=service, status=status, message=message)


def _fallback_greeting(
    *,
    user_name: str,
    location: str,
    date: str,
    weather: dict[str, Any] | None,
    calendar: dict[str, Any] | None,
    slack: dict[str, Any] | None,
    services: list[AssistantServiceStatus],
) -> str:
    degraded = [item for item in services if item.status != "ok"]
    intro = (
        f"Good morning, {user_name}. Startup briefing is running with limited generation support."
        if degraded
        else f"Good morning, {user_name}."
    )

    lines = [intro]

    if degraded:
        degraded_text = "; ".join(f"{item.service}: {item.message}" for item in degraded)
        lines.append(f"Unavailable or degraded services are being reported explicitly: {degraded_text}.")

    if calendar is not None:
        lines.append(f"Calendar for {date}: {calendar['summary']}")
    else:
        lines.append("Calendar data is currently unavailable, so I cannot summarize today's schedule reliably.")

    if slack is not None:
        lines.append(
            f"You have {slack['message_count']} Slack message{'s' if slack['message_count'] != 1 else ''} "
            f"waiting from {slack['channel_name']} over the last {slack['lookback_hours']} hours. "
            f"Primary thread: {slack['summary_lines'][0]}"
        )
    else:
        lines.append("Slack message state is currently unavailable, so unread activity cannot be summarized safely.")

    if weather is not None:
        lines.append(
            f"Weather for {location}: {weather['summary']} "
            f"Recommended dress: {weather['recommendation']}"
        )
    else:
        lines.append("Weather data is currently unavailable, so I cannot make a trustworthy clothing recommendation.")

    return "\n\n".join(lines)


def _build_system_prompt(
    *,
    user_name: str,
    location: str,
    date: str,
    services: list[AssistantServiceStatus],
    weather: dict[str, Any] | None,
    calendar: dict[str, Any] | None,
    slack: dict[str, Any] | None,
) -> str:
    service_context = json.dumps(
        [item.model_dump() for item in services],
        ensure_ascii=False,
        separators=(",", ":"),
    )
    context = json.dumps(
        {
            "weather": weather,
            "calendar": calendar,
            "slack": slack,
        },
        ensure_ascii=False,
        separators=(",", ":"),
    )

    return f"""
You are writing the first greeting for an internal AI desktop assistant.

Write in a polished, concise, high-competence tone inspired by a cinematic AI operations assistant.
Do not quote, reference, or imitate any copyrighted dialogue or movie lines.
Do not invent data. If a service is degraded or unavailable, say so explicitly and briefly.

Your job:
- greet {user_name}
- summarize today's schedule
- summarize Slack messages waiting to be read
- summarize today's weather and clothing recommendation
- keep it crisp and confident

Formatting rules:
- plain text only
- 3 short paragraphs maximum
- no bullets
- no markdown

Context date: {date}
Context location: {location}
Service status: {service_context}
Feature context: {context}
""".strip()


def _load_weather(location: str, date: str) -> dict[str, Any]:
    return get_weather_brief(location=location, date=date)


def _load_calendar(date: str) -> dict[str, Any]:
    return get_calendar_brief(date=date)


def _load_slack(
    channel_id: str,
    date: str,
    lookback_hours: int,
) -> dict[str, Any]:
    return summarize_slack_channel(
        channel_id=channel_id,
        user_input="Create the initial assistant greeting for today.",
        date=date,
        lookback_hours=lookback_hours,
    )


def create_startup_greeting(
    *,
    user_name: str,
    location: str,
    date: str,
    channel_id: str | None = None,
    lookback_hours: int | None = None,
) -> StartupGreetingResponse:
    settings = get_settings()

    services: list[AssistantServiceStatus] = [
        _status("backend", "ok", "Jarvis API is reachable."),
    ]

    weather: dict[str, Any] | None = None
    calendar: dict[str, Any] | None = None
    slack: dict[str, Any] | None = None

    selected_channel = channel_id or settings.slack_channel_id or "mock-channel"
    selected_lookback = lookback_hours or settings.slack_lookback_hours

    with ThreadPoolExecutor(max_workers=3) as executor:
        weather_future = executor.submit(_load_weather, location, date)
        calendar_future = executor.submit(_load_calendar, date)
        slack_future = executor.submit(
            _load_slack,
            selected_channel,
            date,
            selected_lookback,
        )

        try:
            weather = weather_future.result()
            services.append(_status("weather", "ok", "Weather briefing is available."))
        except Exception as exc:  # pragma: no cover - defensive
            services.append(_status("weather", "degraded", str(exc)))

        try:
            calendar = calendar_future.result()
            services.append(_status("calendar", "ok", "Calendar briefing is available."))
        except Exception as exc:  # pragma: no cover - defensive
            services.append(_status("calendar", "degraded", str(exc)))

        try:
            slack = slack_future.result()
            services.append(_status("slack", "ok", "Slack summary is available."))
        except Exception as exc:
            services.append(_status("slack", "degraded", str(exc)))

    if not settings.openai_api_key:
        services.append(
            _status(
                "llm",
                "unconfigured",
                "OPENAI_API_KEY is not configured for startup greetings.",
            )
        )
        greeting = _fallback_greeting(
            user_name=user_name,
            location=location,
            date=date,
            weather=weather,
            calendar=calendar,
            slack=slack,
            services=services,
        )
        return StartupGreetingResponse(
            owner=STARTUP_GREETING_OWNER,
            feature=STARTUP_GREETING_FEATURE,
            uses_mock=settings.use_mocks,
            date=date,
            location=location,
            source="fallback",
            greeting=greeting,
            services=services,
        )

    services.append(_status("llm", "ok", f"Startup greeting model {settings.openai_model} is available."))

    payload = {
        "model": settings.openai_model,
        "input": [
            {
                "role": "system",
                "content": _build_system_prompt(
                    user_name=user_name,
                    location=location,
                    date=date,
                    services=services,
                    weather=weather,
                    calendar=calendar,
                    slack=slack,
                ),
            },
            {
                "role": "user",
                "content": "Create the startup greeting now.",
            },
        ],
    }

    try:
        response_payload = _post_openai_responses(payload, api_key=settings.openai_api_key)
        greeting = _extract_output_text(response_payload)
    except Exception as exc:
        services = [
            *services[:-1],
            _status("llm", "degraded", str(exc)),
        ]
        greeting = _fallback_greeting(
            user_name=user_name,
            location=location,
            date=date,
            weather=weather,
            calendar=calendar,
            slack=slack,
            services=services,
        )
        return StartupGreetingResponse(
            owner=STARTUP_GREETING_OWNER,
            feature=STARTUP_GREETING_FEATURE,
            uses_mock=settings.use_mocks,
            date=date,
            location=location,
            source="fallback",
            greeting=greeting,
            services=services,
        )

    if not greeting:
        services = [
            *services[:-1],
            _status("llm", "degraded", "OpenAI returned an empty startup greeting."),
        ]
        greeting = _fallback_greeting(
            user_name=user_name,
            location=location,
            date=date,
            weather=weather,
            calendar=calendar,
            slack=slack,
            services=services,
        )
        return StartupGreetingResponse(
            owner=STARTUP_GREETING_OWNER,
            feature=STARTUP_GREETING_FEATURE,
            uses_mock=settings.use_mocks,
            date=date,
            location=location,
            source="fallback",
            greeting=greeting,
            services=services,
        )

    return StartupGreetingResponse(
        owner=STARTUP_GREETING_OWNER,
        feature=STARTUP_GREETING_FEATURE,
        uses_mock=settings.use_mocks,
        date=date,
        location=location,
        source="openai",
        greeting=greeting,
        services=services,
    )
