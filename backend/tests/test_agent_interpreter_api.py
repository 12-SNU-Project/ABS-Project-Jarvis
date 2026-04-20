from __future__ import annotations

import json


def test_agent_interpret_requires_openai_api_key(client, monkeypatch) -> None:
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)

    response = client.post(
        "/api/v1/agent/interpret",
        json={
            "input": "Change the 기획리뷰. Defer it 30 minutes.",
            "date": "2026-04-18",
            "calendar_id": "primary",
        },
    )

    assert response.status_code == 503
    assert response.json() == {
        "error": {
            "code": "openai_not_configured",
            "message": "OPENAI_API_KEY is not configured for the backend agent interpreter.",
            "details": [],
        }
    }


def test_agent_interpret_normalizes_natural_language_command(
    client, monkeypatch
) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")

    def fake_post_openai_responses(body, *, api_key: str):
        assert api_key == "test-key"
        assert body["model"] == "gpt-5.4-mini"
        assert body["text"]["format"]["type"] == "json_object"

        return {
            "output": [
                {
                    "type": "message",
                    "content": [
                        {
                            "type": "output_text",
                            "text": json.dumps(
                                {
                                    "status": "interpreted",
                                    "command": "move event evt-3 to 2026-04-18 from 15:30 to 16:30 calendar primary",
                                    "explanation": "Matched 기획리뷰 to evt-3 and shifted it by 30 minutes.",
                                },
                                ensure_ascii=False,
                            ),
                        }
                    ],
                }
            ]
        }

    monkeypatch.setattr(
        "app.services.agent_interpreter._post_openai_responses",
        fake_post_openai_responses,
    )

    response = client.post(
        "/api/v1/agent/interpret",
        json={
            "input": "Change the 기획리뷰. Defer it 30 minutes.",
            "date": "2026-04-18",
            "calendar_id": "primary",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["owner"] == "agent"
    assert payload["feature"] == "agent_interpreter"
    assert payload["uses_mock"] is True
    assert payload["status"] == "interpreted"
    assert payload["source"] == "openai"
    assert (
        payload["command"]
        == "move event evt-3 to 2026-04-18 from 15:30 to 16:30 calendar primary"
    )
    assert payload["explanation"] == "Matched 기획리뷰 to evt-3 and shifted it by 30 minutes."
    assert len(payload["tool_calls"]) == 1
    assert payload["tool_calls"][0]["name"] == "create_calendar_operation_proposal"
    assert payload["tool_calls"][0]["method"] == "POST"
    assert payload["tool_calls"][0]["path"] == "/api/v1/calendar-operations/proposals"
    assert payload["tool_calls"][0]["body"]["operation_type"] == "move_event"
    assert payload["tool_calls"][0]["body"]["event_id"] == "evt-3"


def test_agent_interpret_converts_unsupported_interpreted_command_to_clarify(
    client, monkeypatch
) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")

    def fake_post_openai_responses(body, *, api_key: str):
        assert api_key == "test-key"
        return {
            "output": [
                {
                    "type": "message",
                    "content": [
                        {
                            "type": "output_text",
                            "text": json.dumps(
                                {
                                    "status": "interpreted",
                                    "command": "open browser and send email",
                                    "explanation": "I can do this.",
                                },
                                ensure_ascii=False,
                            ),
                        }
                    ],
                }
            ]
        }

    monkeypatch.setattr(
        "app.services.agent_interpreter._post_openai_responses",
        fake_post_openai_responses,
    )

    response = client.post(
        "/api/v1/agent/interpret",
        json={
            "input": "브라우저 열어서 이메일 보내줘.",
            "date": "2026-04-18",
            "calendar_id": "primary",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "clarify"
    assert payload["command"] is None
    assert payload["tool_calls"] == []
    assert payload["explanation"].startswith("Unsupported:")


def test_agent_interpret_sends_normalized_user_input_to_model(
    client, monkeypatch
) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")

    def fake_post_openai_responses(body, *, api_key: str):
        assert api_key == "test-key"
        user_content = body["input"][1]["content"]
        assert "Raw input:" in user_content
        assert "Normalized input:" in user_content
        assert "오후 3시 반" in user_content
        assert "15:30" in user_content
        return {
            "output": [
                {
                    "type": "message",
                    "content": [
                        {
                            "type": "output_text",
                            "text": json.dumps(
                                {
                                    "status": "interpreted",
                                    "command": "show calendars",
                                    "explanation": "Used normalized time expression.",
                                },
                                ensure_ascii=False,
                            ),
                        }
                    ],
                }
            ]
        }

    monkeypatch.setattr(
        "app.services.agent_interpreter._post_openai_responses",
        fake_post_openai_responses,
    )

    response = client.post(
        "/api/v1/agent/interpret",
        json={
            "input": "오늘 오후 3시 반 미팅 일정 보여줘",
            "date": "2026-04-18",
            "calendar_id": "primary",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["status"] == "interpreted"
    assert payload["command"] == "show calendars"
    assert payload["tool_calls"][0]["name"] == "list_calendars"
