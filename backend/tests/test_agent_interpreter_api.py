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
        "app.services.assistant.interpreter._post_openai_responses",
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
    assert response.json() == {
        "owner": "agent",
        "feature": "agent_interpreter",
        "uses_mock": True,
        "status": "interpreted",
        "source": "openai",
        "command": "move event evt-3 to 2026-04-18 from 15:30 to 16:30 calendar primary",
        "explanation": "Matched 기획리뷰 to evt-3 and shifted it by 30 minutes.",
    }
