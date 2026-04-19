from __future__ import annotations

from app.services.slack_summary import get_slack_brief, summarize_slack_channel


def test_summarize_slack_channel_uses_mock_by_default() -> None:
    response = summarize_slack_channel(
        channel_id="C_TEST",
        user_input="최근 내용 정리해줘",
        date="2026-04-18",
        lookback_hours=24,
    )

    assert response["uses_mock"] is True
    assert response["channel_id"] == "C_TEST"
    assert response["lookback_hours"] == 24
    assert len(response["summary_lines"]) == 5
    assert response["message_count"] >= 1


def test_get_slack_brief_preserves_existing_contract() -> None:
    response = get_slack_brief(user_input="브리핑 해줘", date="2026-04-18")

    assert response["feature"] == "slack_summary"
    assert response["date"] == "2026-04-18"
    assert isinstance(response["channels"], list)
    assert len(response["channels"]) == 1
