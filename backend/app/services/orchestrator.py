from __future__ import annotations

import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from app.core.config import get_settings
from app.services.admin import get_admin_summary
from app.services.calendar import get_calendar_brief
from app.services.presentation import get_presentation_demo
from app.services.slack_summary import get_slack_brief
from app.services.weather import get_weather_brief
from app.schemas.schemas import FinalBriefing


def _build_fallback_summary(
    weather: dict,
    calendar: dict,
    slack: dict,
    admin: dict,
    presentation: dict,
) -> str:
    calendar_conflict = ""
    if calendar.get("conflicts"):
        calendar_conflict = f" 일정 충돌은 {', '.join(calendar['conflicts'])}입니다."

    slack_actions: list[str] = []
    for channel in slack.get("channels", []):
        slack_actions.extend(channel.get("action_items", []))
    top_actions = ", ".join(slack_actions[:2]) if slack_actions else "확인할 액션 아이템은 아직 없습니다"

    return (
        f"{weather['summary']} "
        f"{calendar['summary']}{calendar_conflict} "
        f"{slack['summary']} "
        f"우선 확인할 슬랙 액션은 {top_actions}입니다. "
        f"오늘 가장 토큰 사용량이 큰 기능은 {admin['top_token_feature']}이고, "
        f"데모 마무리 메시지는 '{presentation['closing_message']}'입니다."
    )


def _generate_final_summary(
    *,
    user_input: str,
    location: str,
    date: str,
    user_name: str,
    weather: dict,
    calendar: dict,
    slack: dict,
    admin: dict,
    presentation: dict,
) -> str:
    settings = get_settings()
    fallback_summary = _build_fallback_summary(weather, calendar, slack, admin, presentation)

    if settings.use_mocks or not settings.openai_api_key:
        return fallback_summary

    try:
        payload = {
            "model": settings.openai_model,
            "instructions": (
                "당신은 개인 비서 Jarvis입니다. 제공된 데이터를 바탕으로 아침 브리핑 최종 요약을 한국어로 작성하세요. "
                "3~5문장으로 간결하게 쓰고, 중요한 일정, 날씨, 슬랙 액션아이템, admin 상태, 발표 포인트를 자연스럽게 묶어 주세요."
            ),
            "input": (
                f"사용자 이름: {user_name}\n"
                f"사용자 요청: {user_input}\n"
                f"위치: {location}\n"
                f"기준 날짜: {date}\n\n"
                f"[날씨]\n{weather}\n\n"
                f"[일정]\n{calendar}\n\n"
                f"[슬랙]\n{slack}\n\n"
                f"[관리자 요약]\n{admin}\n\n"
                f"[발표 데모]\n{presentation}\n"
            ),
        }
        request = Request(
            url="https://api.openai.com/v1/responses",
            data=json.dumps(payload).encode("utf-8"),
            headers={
                "Authorization": f"Bearer {settings.openai_api_key}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        with urlopen(request, timeout=30) as response:
            response_data = json.loads(response.read().decode("utf-8"))
        summary = str(response_data.get("output_text", "")).strip()
        return summary or fallback_summary
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError, OSError):
        return fallback_summary


def create_briefing(user_input: str, location: str, date: str, user_name: str) -> FinalBriefing:
    weather = get_weather_brief(location=location, date=date)
    calendar = get_calendar_brief(date=date)
    slack = get_slack_brief(user_input=user_input, date=date)
    admin = get_admin_summary()
    presentation = get_presentation_demo()
    final_summary = _generate_final_summary(
        user_input=user_input,
        location=location,
        date=date,
        user_name=user_name,
        weather=weather,
        calendar=calendar,
        slack=slack,
        admin=admin,
        presentation=presentation,
    )

    return FinalBriefing(
        headline=f"{user_name}님을 위한 Jarvis 아침 브리핑",
        generated_for=date,
        user_input=user_input,
        weather=weather,
        calendar=calendar,
        slack=slack,
        admin=admin,
        presentation=presentation,
        final_summary=final_summary,
    )
