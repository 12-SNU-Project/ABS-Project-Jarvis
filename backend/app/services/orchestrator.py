from __future__ import annotations

from app.services.admin import get_admin_summary
from app.services.calendar import get_calendar_brief
from app.services.presentation import get_presentation_demo
from app.services.slack_summary import get_slack_brief
from app.services.weather import get_weather_brief
from app.schemas.schemas import FinalBriefing


def create_briefing(user_input: str, location: str, date: str, user_name: str) -> FinalBriefing:
    # TODO(배민규): 이 함수 하나만 수정하면 됩니다.
    weather = get_weather_brief(location=location, date=date)
    calendar = get_calendar_brief(date=date)
    slack = get_slack_brief(user_input=user_input, date=date)
    admin = get_admin_summary()
    presentation = get_presentation_demo()

    return FinalBriefing(
        headline=f"{user_name}님을 위한 Jarvis 아침 브리핑",
        generated_for=date,
        user_input=user_input,
        weather=weather,
        calendar=calendar,
        slack=slack,
        admin=admin,
        presentation=presentation,
        final_summary=(
            f"{weather['summary']} "
            f"{calendar['summary']} "
            f"{slack['summary']} "
            f"오늘 가장 토큰 사용량이 큰 기능은 {admin['top_token_feature']}입니다."
        ),
    )
