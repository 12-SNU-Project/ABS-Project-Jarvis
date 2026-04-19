from __future__ import annotations

import base64
from io import BytesIO
from typing import Any

from openai import OpenAI

from app.core.config import get_settings
from app.core.errors import AppError
from app.schemas.schemas import VoiceSpeechResponse, VoiceTranscriptionResponse


VOICE_OWNER = "voice"
VOICE_FEATURE = "voice"

_MIME_BY_FORMAT = {
    "mp3": "audio/mpeg",
    "wav": "audio/wav",
    "opus": "audio/opus",
    "aac": "audio/aac",
    "flac": "audio/flac",
    "pcm": "audio/pcm",
}


def _get_openai_client() -> OpenAI:
    settings = get_settings()
    if not settings.openai_api_key:
        raise AppError(
            code="openai_not_configured",
            message="OPENAI_API_KEY is not configured for backend voice services.",
            status_code=503,
        )

    return OpenAI(
        api_key=settings.openai_api_key,
        timeout=settings.openai_timeout_seconds,
    )


def _coerce_text_response(value: Any) -> str:
    if isinstance(value, str):
        return value.strip()

    text = getattr(value, "text", None)
    if isinstance(text, str):
        return text.strip()

    if hasattr(value, "model_dump"):
        payload = value.model_dump()
        if isinstance(payload, dict) and isinstance(payload.get("text"), str):
            return payload["text"].strip()

    return str(value).strip()


def _coerce_audio_bytes(value: Any) -> bytes:
    if isinstance(value, bytes):
        return value

    read = getattr(value, "read", None)
    if callable(read):
        data = read()
        if isinstance(data, bytes):
            return data

    content = getattr(value, "content", None)
    if isinstance(content, bytes):
        return content

    raise AppError(
        code="voice_invalid_response",
        message="Voice generation returned an unsupported audio payload.",
        status_code=502,
    )


def _transcribe_with_openai(
    *,
    audio_bytes: bytes,
    filename: str,
    content_type: str | None,
) -> str:
    settings = get_settings()
    client = _get_openai_client()

    audio_file = BytesIO(audio_bytes)
    audio_file.name = filename

    result = client.audio.transcriptions.create(
        model=settings.openai_transcription_model,
        file=audio_file,
        response_format="text",
    )

    transcript = _coerce_text_response(result)
    if not transcript:
        raise AppError(
            code="voice_empty_transcript",
            message="Voice transcription returned no text.",
            status_code=502,
        )

    return transcript


def _synthesize_with_openai(
    *,
    text: str,
    instructions: str | None,
    voice: str,
    response_format: str,
) -> bytes:
    settings = get_settings()
    client = _get_openai_client()

    result = client.audio.speech.create(
        model=settings.openai_tts_model,
        voice=voice,
        input=text,
        instructions=instructions or "Speak clearly and professionally.",
        response_format=response_format,
    )
    return _coerce_audio_bytes(result)


def transcribe_audio(
    *,
    audio_bytes: bytes,
    filename: str,
    content_type: str | None,
) -> VoiceTranscriptionResponse:
    settings = get_settings()
    transcript = _transcribe_with_openai(
        audio_bytes=audio_bytes,
        filename=filename,
        content_type=content_type,
    )

    return VoiceTranscriptionResponse(
        owner=VOICE_OWNER,
        feature=VOICE_FEATURE,
        uses_mock=settings.use_mocks,
        transcript=transcript,
        filename=filename,
        content_type=content_type or "application/octet-stream",
        model=settings.openai_transcription_model,
        source="openai",
    )


def synthesize_speech(
    *,
    text: str,
    instructions: str | None = None,
    voice: str | None = None,
    response_format: str = "wav",
) -> VoiceSpeechResponse:
    settings = get_settings()
    selected_voice = voice or settings.openai_tts_voice
    selected_format = response_format or "wav"

    audio_bytes = _synthesize_with_openai(
        text=text,
        instructions=instructions,
        voice=selected_voice,
        response_format=selected_format,
    )

    return VoiceSpeechResponse(
        owner=VOICE_OWNER,
        feature=VOICE_FEATURE,
        uses_mock=settings.use_mocks,
        text=text,
        model=settings.openai_tts_model,
        voice=selected_voice,
        response_format=selected_format,
        mime_type=_MIME_BY_FORMAT.get(selected_format, "application/octet-stream"),
        audio_base64=base64.b64encode(audio_bytes).decode("ascii"),
        source="openai",
    )

