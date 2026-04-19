from __future__ import annotations


def test_startup_greeting_falls_back_when_openai_not_configured(
    client, monkeypatch
) -> None:
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)

    response = client.post(
        "/api/v1/assistant/startup-greeting",
        json={
            "user_name": "Morgan",
            "location": "Seoul",
            "date": "2026-04-18",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["feature"] == "startup_greeting"
    assert payload["source"] == "fallback"
    assert "Morgan" in payload["greeting"]
    assert "OPENAI_API_KEY is not configured" in payload["greeting"]
    assert any(
        item == {
            "service": "llm",
            "status": "unconfigured",
            "message": "OPENAI_API_KEY is not configured for startup greetings.",
        }
        for item in payload["services"]
    )


def test_startup_greeting_uses_openai_when_configured(client, monkeypatch) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")

    def fake_post_openai_responses(body, *, api_key: str):
        assert api_key == "test-key"
        assert body["model"] == "gpt-5.4-mini"
        assert "Create the startup greeting now." in body["input"][1]["content"]
        return {
            "output_text": (
                "Good morning, Morgan. Your schedule is loaded, Slack activity is ready for review, "
                "and the weather suggests a light layer for the day."
            )
        }

    monkeypatch.setattr(
        "app.services.assistant.startup_greeting._post_openai_responses",
        fake_post_openai_responses,
    )

    response = client.post(
        "/api/v1/assistant/startup-greeting",
        json={
            "user_name": "Morgan",
            "location": "Seoul",
            "date": "2026-04-18",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["source"] == "openai"
    assert payload["greeting"].startswith("Good morning, Morgan.")
    assert any(item["service"] == "weather" and item["status"] == "ok" for item in payload["services"])
    assert any(item["service"] == "calendar" and item["status"] == "ok" for item in payload["services"])
    assert any(item["service"] == "slack" and item["status"] == "ok" for item in payload["services"])
    assert any(item["service"] == "llm" and item["status"] == "ok" for item in payload["services"])
