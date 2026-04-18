from __future__ import annotations

from jarvis.core.mock_loader import load_mock


def get_weather_brief(location: str, date: str) -> dict:
    # TODO(조수빈): 이 함수 하나만 수정하면 됩니다.
    # 입력:
    # - location: 사용자의 위치 문자열
    # - date: 브리핑 기준 날짜 문자열
    # 출력:
    # - 아래 dict 구조를 그대로 유지한 채 실제 날씨/옷 추천 데이터로 교체
    # 작업 방식:
    # - 지금은 mock 데이터를 읽지만, 나중에는 weather API 호출로 바꾸면 됩니다.
    # - 시간이 없으면 먼저 src/jarvis/data/mocks/weather.json 기준으로 완성하면 됩니다.
    data = load_mock("weather")
    return {
        "owner": "조수빈",
        "feature": "weather",
        "location": location,
        "date": date,
        "summary": f"{location} 기준 {data['summary']}",
        "temperature_c": data["temperature_c"],
        "condition": data["condition"],
        "recommendation": data["recommendation"],
        "items": data["items"],
        "uses_mock": True,
    }
