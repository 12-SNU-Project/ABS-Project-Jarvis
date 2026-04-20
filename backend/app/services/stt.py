from __future__ import annotations

import base64
import io
from binascii import Error as BinasciiError

from openai import OpenAI

from app.core.config import get_settings
from app.core.errors import AppError, error_detail
from app.schemas.schemas import SttTranscribeResponse


STT_OWNER = "voice"
STT_FEATURE = "speech_to_text"
MAX_AUDIO_BYTES = 8 * 1024 * 1024


def _decode_audio_base64(audio_base64: str) -> bytes:
    encoded = audio_base64.strip()
    if not encoded:
        raise AppError(
            code="invalid_audio_base64",
            message="audio_base64 must not be empty.",
            status_code=422,
            details=[
                error_detail(
                    code="invalid_audio_base64",
                    message="audio_base64 must not be empty.",
                    field="audio_base64",
                )
            ],
        )

    try:
        audio_bytes = base64.b64decode(encoded, validate=True)
    except BinasciiError as exc:
        raise AppError(
            code="invalid_audio_base64",
            message="audio_base64 must be valid base64 data.",
            status_code=422,
            details=[
                error_detail(
                    code="invalid_audio_base64",
                    message="audio_base64 must be valid base64 data.",
                    field="audio_base64",
                )
            ],
        ) from exc

    if not audio_bytes:
        raise AppError(
            code="empty_audio_payload",
            message="Decoded audio payload is empty.",
            status_code=422,
            details=[
                error_detail(
                    code="empty_audio_payload",
                    message="Decoded audio payload is empty.",
                    field="audio_base64",
                )
            ],
        )

    if len(audio_bytes) > MAX_AUDIO_BYTES:
        raise AppError(
            code="audio_payload_too_large",
            message="Audio payload exceeds the 8MB limit.",
            status_code=413,
            details=[
                error_detail(
                    code="audio_payload_too_large",
                    message="Audio payload exceeds the 8MB limit.",
                    field="audio_base64",
                )
            ],
        )

    return audio_bytes


def _filename_for_mime(mime_type: str) -> str:
    normalized = mime_type.strip().lower()
    if normalized == "audio/mp3":
        return "recording.mp3"
    if normalized == "audio/mpeg":
        return "recording.mp3"
    if normalized == "audio/ogg":
        return "recording.ogg"
    if normalized == "audio/webm":
        return "recording.webm"
    return "recording.wav"


def _transcribe_with_openai(
    *,
    audio_bytes: bytes,
    mime_type: str,
    language: str,
    prompt: str | None,
    model: str,
    api_key: str,
) -> str:
    stream = io.BytesIO(audio_bytes)
    stream.name = _filename_for_mime(mime_type)

    client = OpenAI(api_key=api_key)
    request_payload: dict[str, object] = {
        "model": model,
        "file": stream,
        "language": language,
    }
    prompt_value = (prompt or "").strip()
    if prompt_value:
        request_payload["prompt"] = prompt_value

    response = client.audio.transcriptions.create(**request_payload)
    transcript = str(getattr(response, "text", "")).strip()
    if transcript:
        return transcript
    raise AppError(
        code="openai_empty_response",
        message="OpenAI returned an empty transcription.",
        status_code=502,
    )


def transcribe_audio(
    *,
    audio_base64: str,
    mime_type: str,
    language: str,
    prompt: str | None = None,
) -> SttTranscribeResponse:
    settings = get_settings()
    normalized_language = language.strip() or "ko"
    audio_bytes = _decode_audio_base64(audio_base64)

    if settings.use_mocks:
        return SttTranscribeResponse(
            owner=STT_OWNER,
            feature=STT_FEATURE,
            uses_mock=True,
            source="mock",
            model="mock-stt",
            language=normalized_language,
            transcript="모의 음성 인식 결과입니다. 백엔드 실환경에서 OPENAI_API_KEY를 설정하면 실제 인식이 동작합니다.",
        )

    if not settings.openai_api_key:
        raise AppError(
            code="openai_not_configured",
            message="OPENAI_API_KEY is not configured for speech transcription.",
            status_code=503,
        )

    try:
        transcript = _transcribe_with_openai(
            audio_bytes=audio_bytes,
            mime_type=mime_type,
            language=normalized_language,
            prompt=prompt,
            model=settings.openai_stt_model,
            api_key=settings.openai_api_key,
        )
    except AppError:
        raise
    except Exception as exc:
        raise AppError(
            code="openai_request_failed",
            message=f"OpenAI transcription request failed: {exc}",
            status_code=502,
        ) from exc

    return SttTranscribeResponse(
        owner=STT_OWNER,
        feature=STT_FEATURE,
        uses_mock=False,
        source="openai",
        model=settings.openai_stt_model,
        language=normalized_language,
        transcript=transcript,
    )
