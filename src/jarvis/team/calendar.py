from __future__ import annotations

from jarvis.core.mock_loader import load_mock


def get_calendar_brief(date: str) -> dict:
    # TODO(김재희): 이 함수 하나만 수정하면 됩니다.
    # 입력:
    # - date: 브리핑 기준 날짜 문자열
    # 출력:
    # - 아래 dict 구조를 그대로 유지한 채 실제 일정 데이터로 교체
    # 작업 방식:
    # - 지금은 mock 데이터를 읽지만, 나중에는 Google Calendar 등 실제 일정 소스로 바꾸면 됩니다.
    # - 시간이 없으면 먼저 src/jarvis/data/mocks/calendar.json 기준으로 완성하면 됩니다.
    data = load_mock("calendar")
    return {
        "owner": "김재희",
        "feature": "calendar",
        "date": date,
        "summary": f"{date} 일정 기준 {data['summary']}",
        "events": data["events"],
        "conflicts": data["conflicts"],
        "uses_mock": True,
    }
