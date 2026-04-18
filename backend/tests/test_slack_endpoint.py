from __future__ import annotations

from fastapi.testclient import TestClient

from main import app


client = TestClient(app)


def test_slack_summary_endpoint_returns_mock_response() -> None:
    response = client.post(
        "/slack/summary",
        json={
            "channel_id": "C1234567890",
            "user_input": "최근 1일 대화 핵심을 5줄로 요약해줘",
            "date": "2026-04-18",
            "lookback_hours": 24,
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["feature"] == "slack_summary"
    assert body["channel_id"] == "C1234567890"
    assert body["uses_mock"] is True
    assert body["lookback_hours"] == 24
    assert len(body["summary_lines"]) == 5
