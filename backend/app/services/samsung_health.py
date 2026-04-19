from __future__ import annotations

from datetime import datetime, timezone
from urllib.error import HTTPError, URLError

from app.core.config import get_settings
from app.providers.mock_provider import load_mock
from app.providers.samsung_health_provider import fetch_samsung_health_data


def _pick(data: dict, *keys: str) -> object | None:
    for key in keys:
        if key in data and data[key] is not None:
            return data[key]
    return None


def _as_int(value: object) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _build_summary(status: str, wake_time: str | None, sleep_duration_minutes: int | None) -> str:
    if status == "awake" and wake_time and sleep_duration_minutes is not None:
        return f"마지막 기상 시각은 {wake_time}이고 총 수면 시간은 {sleep_duration_minutes}분입니다."
    if status == "sleeping" and sleep_duration_minutes is not None:
        return f"현재 수면 상태로 보이며 최근 수면 누적 시간은 {sleep_duration_minutes}분입니다."
    if wake_time:
        return f"마지막으로 감지된 기상 시각은 {wake_time}입니다."
    return "삼성 헬스 기상 정보를 아직 확인하지 못했습니다."


def _normalize_health_payload(data: dict, source: str, uses_mock: bool) -> dict:
    detected_at = _pick(data, "detected_at", "detectedAt")
    wake_time = _pick(data, "wake_time", "wakeTime", "last_wake_time", "lastWakeTime")
    sleep_start = _pick(data, "sleep_start", "sleepStart")
    sleep_end = _pick(data, "sleep_end", "sleepEnd")
    sleep_duration_minutes = _as_int(
        _pick(data, "sleep_duration_minutes", "sleepDurationMinutes", "duration_minutes", "durationMinutes")
    )
    raw_status = _pick(data, "status", "sleep_status", "sleepStatus")
    status = str(raw_status).lower() if raw_status is not None else "unknown"
    if status not in {"awake", "sleeping", "unknown"}:
        status = "awake" if wake_time else "unknown"

    summary = _pick(data, "summary")
    if not isinstance(summary, str) or not summary.strip():
        summary = _build_summary(status=status, wake_time=str(wake_time) if wake_time else None, sleep_duration_minutes=sleep_duration_minutes)

    return {
        "source": source,
        "uses_mock": uses_mock,
        "detected_at": str(detected_at or datetime.now(timezone.utc).isoformat()),
        "wake_time": str(wake_time) if wake_time is not None else None,
        "sleep_start": str(sleep_start) if sleep_start is not None else None,
        "sleep_end": str(sleep_end) if sleep_end is not None else None,
        "sleep_duration_minutes": sleep_duration_minutes,
        "status": status,
        "summary": summary,
    }


def _mock_health_summary() -> dict:
    data = load_mock("samsung_health")
    return _normalize_health_payload(data, source="mock", uses_mock=True)


def get_samsung_health_summary() -> dict:
    settings = get_settings()
    if settings.samsung_health_use_mock:
        return _mock_health_summary()

    if not settings.samsung_health_api_url:
        fallback = _mock_health_summary()
        fallback["status"] = "unknown"
        fallback["summary"] = "삼성 헬스 API URL이 설정되지 않아 mock 데이터를 기준으로 응답합니다."
        return fallback

    try:
        data = fetch_samsung_health_data(
            api_url=settings.samsung_health_api_url,
            api_key=settings.samsung_health_api_key,
        )
        return _normalize_health_payload(data, source="samsung_health", uses_mock=False)
    except (HTTPError, URLError, TimeoutError, ValueError, OSError):
        fallback = _mock_health_summary()
        fallback["status"] = "unknown"
        fallback["summary"] = "삼성 헬스 연동에 실패해 mock 데이터를 기준으로 응답합니다."
        return fallback
