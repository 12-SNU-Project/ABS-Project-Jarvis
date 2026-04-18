from __future__ import annotations

from app.providers.mock_provider import load_mock


def get_slack_brief(user_input: str, date: str) -> dict:
    # TODO(문이현): 이 함수 하나만 수정하면 됩니다.
    # 입력:
    # - user_input: 사용자가 요청한 자연어 문장
    # - date: 브리핑 기준 날짜 문자열
    # 출력:
    # - 아래 dict 구조를 그대로 유지한 채 실제 Slack 요약 결과로 교체
    # 작업 방식:
    # - 지금은 mock 데이터를 읽지만, 나중에는 Slack API + 요약 로직으로 바꾸면 됩니다.
    # - 시간이 없으면 먼저 src/jarvis/data/mocks/slack.json 기준으로 완성하면 됩니다.
    data = load_mock("slack")
    return {
        "owner": "문이현",
        "feature": "slack_summary",
        "date": date,
        "summary": f"'{user_input}' 요청과 관련해 {data['summary']}",
        "channels": data["channels"],
        "uses_mock": True,
    }
