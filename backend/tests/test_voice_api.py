from __future__ import annotations


def test_voice_transcribe_requires_openai_api_key(client, monkeypatch) -> None:
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)

    response = client.post(
        "/api/v1/voice/transcribe",
        files={"audio": ("sample.webm", b"fake-audio", "audio/webm")},
    )

    assert response.status_code == 503
    assert response.json() == {
        "error": {
            "code": "openai_not_configured",
            "message": "OPENAI_API_KEY is not configured for backend voice services.",
            "details": [],
        }
    }


def test_voice_transcribe_returns_openai_transcript(client, monkeypatch) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")

    def fake_transcribe(*, audio_bytes: bytes, filename: str, content_type: str | None) -> str:
        assert audio_bytes == b"fake-audio"
        assert filename == "sample.webm"
        assert content_type == "audio/webm"
        return "Please move the review by thirty minutes."

    monkeypatch.setattr("app.voice.service._transcribe_with_openai", fake_transcribe)

    response = client.post(
        "/api/v1/voice/transcribe",
        files={"audio": ("sample.webm", b"fake-audio", "audio/webm")},
    )

    assert response.status_code == 200
    assert response.json() == {
        "owner": "voice",
        "feature": "voice",
        "uses_mock": True,
        "transcript": "Please move the review by thirty minutes.",
        "filename": "sample.webm",
        "content_type": "audio/webm",
        "model": "gpt-4o-transcribe",
        "source": "openai",
    }


def test_voice_speak_returns_audio_payload(client, monkeypatch) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")

    def fake_synthesize(
        *,
        text: str,
        instructions: str | None,
        voice: str,
        response_format: str,
    ) -> bytes:
        assert text == "Good morning. Systems are ready."
        assert instructions == "Speak in a poised, concise assistant tone."
        assert voice == "cedar"
        assert response_format == "wav"
        return b"voice-bytes"

    monkeypatch.setattr("app.voice.service._synthesize_with_openai", fake_synthesize)

    response = client.post(
        "/api/v1/voice/speak",
        json={
            "text": "Good morning. Systems are ready.",
            "instructions": "Speak in a poised, concise assistant tone.",
        },
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["owner"] == "voice"
    assert payload["feature"] == "voice"
    assert payload["uses_mock"] is True
    assert payload["text"] == "Good morning. Systems are ready."
    assert payload["model"] == "gpt-4o-mini-tts"
    assert payload["voice"] == "cedar"
    assert payload["response_format"] == "wav"
    assert payload["mime_type"] == "audio/wav"
    assert payload["source"] == "openai"
    assert payload["audio_base64"] == "dm9pY2UtYnl0ZXM="
