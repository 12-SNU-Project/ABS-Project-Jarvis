from __future__ import annotations

import base64


def _sample_audio_base64() -> str:
    # Minimal WAV-like header bytes are enough for mock and patched tests.
    audio_bytes = b"RIFF\x24\x00\x00\x00WAVEfmt "
    return base64.b64encode(audio_bytes).decode("ascii")


def test_stt_transcribe_returns_mock_response(client) -> None:
    response = client.post(
        "/api/v1/stt/transcribe",
        json={
            "audio_base64": _sample_audio_base64(),
            "mime_type": "audio/wav",
            "language": "ko",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["owner"] == "voice"
    assert body["feature"] == "speech_to_text"
    assert body["uses_mock"] is True
    assert body["source"] == "mock"
    assert body["language"] == "ko"
    assert body["transcript"]


def test_stt_transcribe_rejects_invalid_base64(client) -> None:
    response = client.post(
        "/api/v1/stt/transcribe",
        json={
            "audio_base64": "@@@not-base64@@@",
            "mime_type": "audio/wav",
            "language": "ko",
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_audio_base64"


def test_stt_transcribe_requires_openai_api_key(client, monkeypatch) -> None:
    monkeypatch.setenv("JARVIS_USE_MOCKS", "false")
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)

    response = client.post(
        "/api/v1/stt/transcribe",
        json={
            "audio_base64": _sample_audio_base64(),
            "mime_type": "audio/wav",
            "language": "ko",
        },
    )

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "openai_not_configured"


def test_stt_transcribe_returns_openai_result(client, monkeypatch) -> None:
    monkeypatch.setenv("JARVIS_USE_MOCKS", "false")
    monkeypatch.setenv("OPENAI_API_KEY", "test-key")
    monkeypatch.setenv("OPENAI_STT_MODEL", "gpt-4o-mini-transcribe")

    def fake_transcribe_with_openai(
        *,
        audio_bytes: bytes,
        mime_type: str,
        language: str,
        prompt: str | None,
        model: str,
        api_key: str,
    ) -> str:
        assert audio_bytes
        assert mime_type == "audio/wav"
        assert language == "ko"
        assert prompt == "회의 용어 위주로 인식"
        assert model == "gpt-4o-mini-transcribe"
        assert api_key == "test-key"
        return "오늘 오후 회의를 30분 미뤄줘."

    monkeypatch.setattr(
        "app.services.stt._transcribe_with_openai",
        fake_transcribe_with_openai,
    )

    response = client.post(
        "/api/v1/stt/transcribe",
        json={
            "audio_base64": _sample_audio_base64(),
            "mime_type": "audio/wav",
            "language": "ko",
            "prompt": "회의 용어 위주로 인식",
        },
    )

    assert response.status_code == 200
    assert response.json() == {
        "owner": "voice",
        "feature": "speech_to_text",
        "uses_mock": False,
        "source": "openai",
        "model": "gpt-4o-mini-transcribe",
        "language": "ko",
        "transcript": "오늘 오후 회의를 30분 미뤄줘.",
    }
