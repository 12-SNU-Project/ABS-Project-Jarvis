from __future__ import annotations

from datetime import datetime, timedelta, timezone
from statistics import mean
from urllib.error import HTTPError, URLError

from app.core.errors import AppError
from app.core.config import get_settings
from app.providers.mock_provider import load_mock
from app.providers.samsung_health_provider import fetch_samsung_health_data
from app.providers.samsung_health_state_provider import (
    load_samsung_health_state,
    save_samsung_health_state,
)


def _planned_data_types() -> list[dict]:
    return [
        {
            "key": "com.samsung.health.sleep",
            "label": "Sleep Session",
            "priority": "high",
            "reason": "기상 시각과 총 수면 시간을 계산해 아침 브리핑 시작 조건과 컨디션 요약에 바로 사용할 수 있습니다.",
        },
        {
            "key": "com.samsung.health.sleep_stage",
            "label": "Sleep Stage",
            "priority": "high",
            "reason": "깊은 수면, REM, 각성 구간을 분석해 브리핑에 수면 질 코멘트를 추가할 수 있습니다.",
        },
        {
            "key": "com.samsung.health.step_daily_trend",
            "label": "Daily Step Trend",
            "priority": "medium",
            "reason": "전일 대비 활동량을 요약해 오늘의 활동 목표나 건강 코멘트를 붙이기 좋습니다.",
        },
        {
            "key": "com.samsung.health.exercise",
            "label": "Exercise Session",
            "priority": "medium",
            "reason": "최근 운동 시간, 운동 종류, 칼로리 소모를 읽어 운동 기반 개인화 브리핑에 활용할 수 있습니다.",
        },
    ]


def _integration_notes() -> str:
    return (
        "Samsung Health Data SDK는 Android 앱에서 HealthDataStore 연결과 PermissionManager 권한 요청 후 "
        "Sleep 데이터를 읽어와야 하며, 프로덕션 배포에는 파트너십 승인이 필요합니다. "
        "개발 단계에서는 Samsung Health 개발자 모드와 Android 브리지 앱으로 선행 검증이 가능합니다."
    )


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


def _resolve_offset(offset_ms: int | None) -> timezone:
    if offset_ms is None:
        return timezone.utc
    return timezone(timedelta(milliseconds=offset_ms))


def _format_epoch_ms(epoch_ms: int | None, offset_ms: int | None) -> str | None:
    if epoch_ms is None:
        return None
    utc_dt = datetime.fromtimestamp(epoch_ms / 1000, tz=timezone.utc)
    return utc_dt.astimezone(_resolve_offset(offset_ms)).isoformat()


def _extract_android_sleep_record(data: dict) -> dict:
    items = data.get("items")
    if isinstance(items, list) and items:
        sleep_items = [item for item in items if isinstance(item, dict)]
        if sleep_items:
            sleep_items.sort(
                key=lambda item: _as_int(_pick(item, "end_time", "endTime")) or 0
            )
            return sleep_items[-1]
    return data


def _build_summary(status: str, wake_time: str | None, sleep_duration_minutes: int | None) -> str:
    if status == "awake" and wake_time and sleep_duration_minutes is not None:
        return f"마지막 기상 시각은 {wake_time}이고 총 수면 시간은 {sleep_duration_minutes}분입니다."
    if status == "sleeping" and sleep_duration_minutes is not None:
        return f"현재 수면 상태로 보이며 최근 수면 누적 시간은 {sleep_duration_minutes}분입니다."
    if wake_time:
        return f"마지막으로 감지된 기상 시각은 {wake_time}입니다."
    return "삼성 헬스 기상 정보를 아직 확인하지 못했습니다."


def _normalize_sleep_item(item: dict, default_status: str) -> dict | None:
    time_offset_ms = _as_int(
        _pick(item, "time_offset", "timeOffset", "offset_ms", "offsetMs")
    )
    start_time_ms = _as_int(_pick(item, "start_time", "startTime"))
    end_time_ms = _as_int(_pick(item, "end_time", "endTime"))
    if start_time_ms is None or end_time_ms is None:
        return None

    sleep_start = _format_epoch_ms(start_time_ms, time_offset_ms)
    sleep_end = _format_epoch_ms(end_time_ms, time_offset_ms)
    duration_minutes = max((end_time_ms - start_time_ms) // 60000, 0)
    status_value = str(
        _pick(item, "status", "sleep_status", "sleepStatus") or default_status or "awake"
    ).lower()
    if status_value not in {"awake", "sleeping", "unknown"}:
        status_value = "awake"

    return {
        "sleep_start": str(sleep_start),
        "sleep_end": str(sleep_end),
        "wake_time": str(sleep_end),
        "sleep_duration_minutes": int(duration_minutes),
        "status": status_value,
    }


def _extract_sleep_history(data: dict, fallback_status: str) -> list[dict]:
    items = data.get("items")
    if not isinstance(items, list):
        items = [data]

    history: list[dict] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        normalized = _normalize_sleep_item(item, fallback_status)
        if normalized is not None:
            history.append(normalized)

    history.sort(key=lambda item: item["sleep_end"], reverse=True)
    return history


def _format_average_wake_time(history: list[dict]) -> str | None:
    if not history:
        return None

    wake_minutes: list[int] = []
    for item in history:
        wake_dt = datetime.fromisoformat(item["wake_time"])
        wake_minutes.append(wake_dt.hour * 60 + wake_dt.minute)

    average_minutes = round(mean(wake_minutes))
    hour = average_minutes // 60
    minute = average_minutes % 60
    sample_dt = datetime.fromisoformat(history[0]["wake_time"])
    average_dt = sample_dt.replace(hour=hour % 24, minute=minute, second=0, microsecond=0)
    return average_dt.isoformat()


def _assistant_actions(history: list[dict], sleep_debt_minutes: int | None) -> list[str]:
    if not history:
        return [
            "수면 데이터가 들어오면 아침 브리핑 시작 시점을 기상 직후로 맞출 수 있습니다.",
        ]

    actions = [
        "최근 수면 이력을 기반으로 오늘 브리핑 시작 시간을 기상 직후로 조정합니다.",
        "평균 수면 시간을 이용해 오늘 밤 권장 취침 시간을 제안할 수 있습니다.",
    ]
    if sleep_debt_minutes and sleep_debt_minutes > 0:
        actions.append("누적 수면 부족이 있으면 저녁 일정 축소나 휴식 알림을 제안할 수 있습니다.")
    else:
        actions.append("수면 패턴이 안정적이면 아침 운동이나 집중 업무 추천에 활용할 수 있습니다.")
    return actions


def _today_sleep_recommendation(
    latest_sleep_minutes: int | None,
    average_sleep_minutes: int | None,
    sleep_debt_minutes: int | None,
) -> str | None:
    target_minutes = 8 * 60
    if latest_sleep_minutes is None:
        return None
    if latest_sleep_minutes < 6 * 60:
        return "오늘은 최소 8시간 수면을 목표로 평소보다 1시간 일찍 취침하는 것을 추천합니다."
    if sleep_debt_minutes is not None and sleep_debt_minutes >= 90:
        return "최근 수면 부족이 누적되어 오늘은 늦은 일정과 카페인 섭취를 줄이고 일찍 쉬는 것이 좋습니다."
    if average_sleep_minutes is not None and average_sleep_minutes < 7 * 60:
        return "최근 평균 수면 시간이 짧아 오늘은 취침 루틴을 앞당겨 7시간 30분 이상 수면을 확보해보세요."
    if latest_sleep_minutes >= target_minutes:
        return "최근 수면 패턴이 안정적이니 현재 취침 시간을 유지해도 좋습니다."
    return "오늘은 평소보다 30분 정도 일찍 취침해 회복 수면을 확보하는 것을 추천합니다."


def _normalize_health_payload(data: dict, source: str, uses_mock: bool) -> dict:
    android_record = _extract_android_sleep_record(data)

    detected_at = _pick(data, "detected_at", "detectedAt")
    time_offset_ms = _as_int(
        _pick(android_record, "time_offset", "timeOffset", "offset_ms", "offsetMs")
    )
    start_time_ms = _as_int(_pick(android_record, "start_time", "startTime"))
    end_time_ms = _as_int(_pick(android_record, "end_time", "endTime"))

    sleep_start = _pick(data, "sleep_start", "sleepStart") or _format_epoch_ms(
        start_time_ms, time_offset_ms
    )
    sleep_end = _pick(data, "sleep_end", "sleepEnd") or _format_epoch_ms(
        end_time_ms, time_offset_ms
    )
    wake_time = _pick(
        data,
        "wake_time",
        "wakeTime",
        "last_wake_time",
        "lastWakeTime",
    ) or sleep_end

    sleep_duration_minutes = _as_int(
        _pick(
            data,
            "sleep_duration_minutes",
            "sleepDurationMinutes",
            "duration_minutes",
            "durationMinutes",
        )
    )
    if sleep_duration_minutes is None and start_time_ms is not None and end_time_ms is not None:
        sleep_duration_minutes = max((end_time_ms - start_time_ms) // 60000, 0)

    raw_status = _pick(data, "status", "sleep_status", "sleepStatus")
    status = str(raw_status).lower() if raw_status is not None else "unknown"
    if status not in {"awake", "sleeping", "unknown"}:
        if end_time_ms is not None or wake_time:
            status = "awake"
        elif start_time_ms is not None:
            status = "sleeping"
        else:
            status = "unknown"

    summary = _pick(data, "summary") or _pick(android_record, "comment", "COMMENT")
    if not isinstance(summary, str) or not summary.strip():
        summary = _build_summary(
            status=status,
            wake_time=str(wake_time) if wake_time else None,
            sleep_duration_minutes=sleep_duration_minutes,
        )

    range_days = _as_int(_pick(data, "range_days", "rangeDays")) or 7
    sleep_history = _extract_sleep_history(data, status)
    recent_nights_count = len(sleep_history)
    average_sleep_duration_minutes = (
        round(mean(item["sleep_duration_minutes"] for item in sleep_history))
        if sleep_history
        else None
    )
    average_wake_time = _format_average_wake_time(sleep_history)
    target_sleep_total = recent_nights_count * 8 * 60
    actual_sleep_total = sum(item["sleep_duration_minutes"] for item in sleep_history)
    sleep_debt_minutes_vs_target = (
        max(target_sleep_total - actual_sleep_total, 0) if recent_nights_count else None
    )
    latest_item = sleep_history[0] if sleep_history else None

    return {
        "source": source,
        "uses_mock": uses_mock,
        "integration_mode": "android_sdk_bridge",
        "partnership_required": True,
        "developer_mode_supported": True,
        "health_data_type": str(
            _pick(data, "health_data_type", "healthDataType") or "com.samsung.health.sleep"
        ),
        "planned_data_types": _planned_data_types(),
        "range_days": range_days,
        "recent_nights_count": recent_nights_count,
        "detected_at": str(detected_at or datetime.now(timezone.utc).isoformat()),
        "wake_time": str(wake_time) if wake_time is not None else None,
        "sleep_start": str(sleep_start) if sleep_start is not None else None,
        "sleep_end": str(sleep_end) if sleep_end is not None else None,
        "sleep_duration_minutes": sleep_duration_minutes,
        "average_sleep_duration_minutes": average_sleep_duration_minutes,
        "average_wake_time": average_wake_time,
        "sleep_debt_minutes_vs_target": sleep_debt_minutes_vs_target,
        "sleep_history": sleep_history,
        "assistant_actions": _assistant_actions(
            history=sleep_history,
            sleep_debt_minutes=sleep_debt_minutes_vs_target,
        ),
        "today_sleep_recommendation": _today_sleep_recommendation(
            latest_sleep_minutes=latest_item["sleep_duration_minutes"] if latest_item else None,
            average_sleep_minutes=average_sleep_duration_minutes,
            sleep_debt_minutes=sleep_debt_minutes_vs_target,
        ),
        "status": status,
        "summary": summary,
        "integration_notes": _integration_notes(),
    }


def _mock_health_summary() -> dict:
    data = load_mock("samsung_health")
    return _normalize_health_payload(data, source="mock", uses_mock=True)


def ingest_samsung_health_payload(payload: dict) -> dict:
    settings = get_settings()
    if not settings.samsung_health_bridge_token:
        raise AppError(
            code="samsung_health_bridge_not_configured",
            message="SAMSUNG_HEALTH_BRIDGE_TOKEN is not configured for bridge ingestion.",
            status_code=503,
            details=[],
        )

    save_samsung_health_state(payload)
    return _normalize_health_payload(payload, source="samsung_health", uses_mock=False)


def get_samsung_health_summary() -> dict:
    settings = get_settings()
    if settings.samsung_health_use_mock:
        return _mock_health_summary()

    cached_state = load_samsung_health_state()
    cached_payload = cached_state.get("payload", {})
    if isinstance(cached_payload, dict) and cached_payload.get("items"):
        return _normalize_health_payload(
            cached_payload,
            source="samsung_health",
            uses_mock=False,
        )

    if not settings.samsung_health_api_url:
        fallback = _mock_health_summary()
        fallback["status"] = "unknown"
        fallback["summary"] = (
            "삼성 헬스 Android 브리지 데이터가 아직 업로드되지 않아 mock 데이터를 기준으로 응답합니다."
        )
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
        fallback["summary"] = (
            "삼성 헬스 Android SDK 브리지 연동에 실패해 mock 데이터를 기준으로 응답합니다."
        )
        return fallback
