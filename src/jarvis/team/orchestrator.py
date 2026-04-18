from __future__ import annotations

from jarvis.team.admin import get_admin_summary
from jarvis.team.calendar import get_calendar_brief
from jarvis.team.presentation import get_presentation_demo
from jarvis.team.slack_summary import get_slack_brief
from jarvis.team.weather import get_weather_brief


def create_briefing(user_input: str, location: str, date: str, user_name: str) -> dict:
    # TODO(배민규): 이 함수 하나만 수정하면 됩니다.
    # 입력:
    # - user_input: 사용자의 자연어 요청
    # - location: 사용자 위치
    # - date: 브리핑 기준 날짜
    # - user_name: 사용자 이름
    # 출력:
    # - 최종 브리핑 dict
    # 작업 방식:
    # - 각 팀원의 결과 dict를 불러와 합치기만 하면 됩니다.
    # - 나중에 필요하면 라우팅, 스케줄링, 실패 처리만 추가하면 됩니다.
    # - 각 팀원이 아직 실데이터를 못 붙여도 mock 출력만 맞으면 전체 브리핑은 완성됩니다.
    weather = get_weather_brief(location=location, date=date)
    calendar = get_calendar_brief(date=date)
    slack = get_slack_brief(user_input=user_input, date=date)
    admin = get_admin_summary()
    presentation = get_presentation_demo()

    return {
        "headline": f"{user_name}님을 위한 Jarvis 아침 브리핑",
        "generated_for": date,
        "user_input": user_input,
        "weather": weather,
        "calendar": calendar,
        "slack": slack,
        "admin": admin,
        "presentation": presentation,
        "final_summary": (
            f"{weather['summary']} "
            f"{calendar['summary']} "
            f"{slack['summary']} "
            f"오늘 가장 토큰 사용량이 큰 기능은 {admin['top_token_feature']}입니다."
        ),
    }
