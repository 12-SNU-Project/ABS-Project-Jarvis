from __future__ import annotations

import json
import math
import os
import re
from datetime import datetime, timedelta
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen
from zoneinfo import ZoneInfo

from app.providers.mock_provider import load_mock

KST = ZoneInfo("Asia/Seoul")
KMA_API_ROOT = "https://apis.data.go.kr/1360000/VilageFcstInfoService_2.0"

KNOWN_LOCATIONS = {
    "seoul": ("서울", 37.5665, 126.9780),
    "서울": ("서울", 37.5665, 126.9780),
    "서울관악구": ("서울 관악구", 37.4782, 126.9518),
    "관악구": ("서울 관악구", 37.4782, 126.9518),
    "gwanak": ("서울 관악구", 37.4782, 126.9518),
    "busan": ("부산", 35.1796, 129.0756),
    "부산": ("부산", 35.1796, 129.0756),
    "incheon": ("인천", 37.4563, 126.7052),
    "인천": ("인천", 37.4563, 126.7052),
    "jeju": ("제주", 33.4996, 126.5312),
    "제주": ("제주", 33.4996, 126.5312),
}

SKY_TO_CONDITION = {
    1: "sunny",
    3: "partly_cloudy",
    4: "cloudy",
}


def _service_key() -> str:
    return os.getenv("KMA_SERVICE_KEY", "").strip() or os.getenv("WEATHER_KMA_SERVICE_KEY", "").strip()


def _normalize_location(location: str) -> str:
    return re.sub(r"\s+", "", location.strip().lower())


def _resolve_location(location: str) -> tuple[str, float, float]:
    return KNOWN_LOCATIONS.get(_normalize_location(location), KNOWN_LOCATIONS["seoul"])


def _request_text(url: str, timeout: float = 8.0) -> str:
    request = Request(url, headers={"User-Agent": "jarvis-weather/0.1"})
    try:
        with urlopen(request, timeout=timeout) as response:
            return response.read().decode("utf-8").strip()
    except HTTPError as error:
        raise RuntimeError(f"KMA API HTTP error: {error.code}") from error
    except URLError as error:
        raise RuntimeError(f"KMA API connection error: {error.reason}") from error


def _to_kma_grid(latitude: float, longitude: float) -> tuple[int, int]:
    re_value = 6371.00877 / 5.0
    slat1 = math.radians(30.0)
    slat2 = math.radians(60.0)
    olon = math.radians(126.0)
    olat = math.radians(38.0)
    xo = 43
    yo = 136

    sn = math.tan(math.pi * 0.25 + slat2 * 0.5) / math.tan(math.pi * 0.25 + slat1 * 0.5)
    sn = math.log(math.cos(slat1) / math.cos(slat2)) / math.log(sn)
    sf = math.tan(math.pi * 0.25 + slat1 * 0.5)
    sf = (sf**sn * math.cos(slat1)) / sn
    ro = math.tan(math.pi * 0.25 + olat * 0.5)
    ro = re_value * sf / (ro**sn)
    ra = math.tan(math.pi * 0.25 + math.radians(latitude) * 0.5)
    ra = re_value * sf / (ra**sn)
    theta = math.radians(longitude) - olon

    if theta > math.pi:
        theta -= 2.0 * math.pi
    if theta < -math.pi:
        theta += 2.0 * math.pi
    theta *= sn

    nx = math.floor(ra * math.sin(theta) + xo + 0.5)
    ny = math.floor(ro - ra * math.cos(theta) + yo + 0.5)
    return nx, ny


def _kma_url(endpoint: str, params: dict[str, str]) -> str:
    key = _service_key()
    query = urlencode({**params, "pageNo": "1", "numOfRows": "1000", "dataType": "JSON"})
    encoded_key = key if "%" in key else quote(key, safe="")
    return f"{KMA_API_ROOT}/{endpoint}?{query}&ServiceKey={encoded_key}"


def _parse_kma_items(text: str) -> list[dict[str, Any]]:
    if text == "Unauthorized":
        raise RuntimeError("KMA API unauthorized")

    payload = json.loads(text)
    header = payload.get("response", {}).get("header", {})
    if header.get("resultCode") and header.get("resultCode") != "00":
        raise RuntimeError(header.get("resultMsg") or f"KMA API error: {header.get('resultCode')}")
    return payload.get("response", {}).get("body", {}).get("items", {}).get("item", [])


def _number(value: Any) -> float | None:
    if value is None:
        return None

    text = str(value).strip()
    if not text or text == "강수없음":
        return 0.0

    match = re.search(r"-?\d+(\.\d+)?", text)
    return float(match.group(0)) if match else None


def _stamp(date_value: str | None, time_value: str | None) -> int:
    return int(f"{date_value or ''}{time_value or ''}" or "0")


def _latest(items: list[dict[str, Any]], category: str) -> dict[str, Any] | None:
    matches = [item for item in items if item.get("category") == category]
    return max(matches, key=lambda item: _stamp(item.get("baseDate"), item.get("baseTime")), default=None)


def _closest(items: list[dict[str, Any]], category: str, target_stamp: int) -> dict[str, Any] | None:
    matches = [item for item in items if item.get("category") == category]
    return min(
        matches,
        key=lambda item: abs(_stamp(item.get("fcstDate"), item.get("fcstTime")) - target_stamp),
        default=None,
    )


def _daily_temperatures(items: list[dict[str, Any]], target_date: str) -> tuple[float | None, float | None]:
    values = [
        value
        for value in (
            _number(item.get("fcstValue"))
            for item in items
            if item.get("category") == "TMP" and item.get("fcstDate") == target_date
        )
        if value is not None
    ]
    return (min(values), max(values)) if values else (None, None)


def _forecast_base_time(now: datetime) -> tuple[str, str]:
    publish_hours = [2, 5, 8, 11, 14, 17, 20, 23]
    effective_hour = now.hour - 1 if now.minute < 10 else now.hour
    for hour in reversed(publish_hours):
        if effective_hour >= hour:
            return now.strftime("%Y%m%d"), f"{hour:02d}00"
    yesterday = now - timedelta(days=1)
    return yesterday.strftime("%Y%m%d"), "2300"


def _condition_from_kma(sky: float | None, precipitation_type: float | None) -> str:
    pty = int(precipitation_type or 0)
    if pty == 1:
        return "rain"
    if pty == 2:
        return "sleet"
    if pty == 3:
        return "snow"
    if pty == 4:
        return "shower"
    return SKY_TO_CONDITION.get(int(sky or 1), "unknown")


def _condition_label(condition: str) -> str:
    return {
        "sunny": "맑음",
        "partly_cloudy": "부분적으로 흐림",
        "cloudy": "흐림",
        "rain": "비",
        "sleet": "진눈깨비",
        "snow": "눈",
        "shower": "소나기",
    }.get(condition, "날씨 정보 확인 중")


def _apparent_temperature(temperature: float, humidity: float, wind_speed_kmh: float) -> float:
    if temperature <= 10 and wind_speed_kmh > 4.8:
        return 13.12 + 0.6215 * temperature - 11.37 * (wind_speed_kmh**0.16) + 0.3965 * temperature * (wind_speed_kmh**0.16)
    if temperature >= 27 and humidity >= 40:
        return temperature + (humidity - 40) * 0.05
    return temperature


def _outfit(temperature: float, apparent: float, min_temp: float, max_temp: float, condition: str, precipitation_probability: float, wind_speed_kmh: float) -> tuple[str, list[str]]:
    items: list[str] = []

    if apparent <= 4:
        recommendation = "니트나 긴팔 이너 위에 코트나 두꺼운 점퍼를 추천합니다."
        items.extend(["heavy coat", "knit", "warm shoes"])
    elif apparent <= 11:
        recommendation = "긴팔 상의와 긴 바지에 자켓이나 트렌치코트를 추천합니다."
        items.extend(["jacket", "long sleeve", "long pants"])
    elif apparent <= 18:
        recommendation = "긴팔 티셔츠나 셔츠 위에 가벼운 자켓을 추천합니다."
        items.extend(["light jacket", "shirt", "sneakers"])
    elif apparent >= 26:
        recommendation = "반팔이나 얇은 셔츠처럼 통풍이 잘 되는 옷을 추천합니다."
        items.extend(["short sleeve", "light shirt", "water bottle"])
    else:
        recommendation = "얇은 긴팔이나 셔츠 중심으로 가볍게 입는 것을 추천합니다."
        items.extend(["shirt", "sneakers"])

    if max_temp - min_temp >= 9 and "light jacket" not in items:
        items.append("light jacket")
    if condition in {"rain", "sleet", "shower"} or precipitation_probability >= 45:
        items.append("umbrella")
    if condition == "snow":
        items.extend(["umbrella", "non-slip shoes"])
    if wind_speed_kmh >= 25 and "windbreaker" not in items:
        items.append("windbreaker")

    return recommendation, list(dict.fromkeys(items))


def _mock_weather(location: str, date: str) -> dict:
    data = load_mock("weather")
    return {
        "owner": "조수빈",
        "feature": "weather",
        "location": location,
        "date": date,
        "summary": f"{location} 기준 {data['summary']}",
        "temperature_c": data["temperature_c"],
        "condition": data["condition"],
        "recommendation": data["recommendation"],
        "items": data["items"],
        "uses_mock": True,
    }


def _real_weather(location: str, date: str) -> dict:
    import time
    from .logging_service import log_feature_run
    start_time = time.time()
    label, latitude, longitude = _resolve_location(location)
    nx, ny = _to_kma_grid(latitude, longitude)
    now = datetime.now(KST)
    current_base = now - timedelta(hours=1)
    forecast_date, forecast_time = _forecast_base_time(now)
    target_date = now.strftime("%Y%m%d")
    target_stamp = int(f"{target_date}{now.strftime('%H00')}")

    current_items = _parse_kma_items(
        _request_text(
            _kma_url(
                "getUltraSrtNcst",
                {
                    "base_date": current_base.strftime("%Y%m%d"),
                    "base_time": current_base.strftime("%H00"),
                    "nx": str(nx),
                    "ny": str(ny),
                },
            )
        )
    )
    forecast_items = _parse_kma_items(
        _request_text(
            _kma_url(
                "getVilageFcst",
                {
                    "base_date": forecast_date,
                    "base_time": forecast_time,
                    "nx": str(nx),
                    "ny": str(ny),
                },
            )
        )
    )

    observed_temp = _number((_latest(current_items, "T1H") or {}).get("obsrValue")) or 0.0
    humidity = _number((_latest(current_items, "REH") or {}).get("obsrValue")) or 0.0
    wind_speed_ms = _number((_latest(current_items, "WSD") or {}).get("obsrValue")) or 0.0
    wind_speed_kmh = wind_speed_ms * 3.6
    forecast_temp = _number((_closest(forecast_items, "TMP", target_stamp) or {}).get("fcstValue"))
    precipitation_probability = _number((_closest(forecast_items, "POP", target_stamp) or {}).get("fcstValue")) or 0.0
    sky = _number((_closest(forecast_items, "SKY", target_stamp) or {}).get("fcstValue"))
    precipitation_type = _number((_closest(forecast_items, "PTY", target_stamp) or {}).get("fcstValue")) or 0.0
    min_temp, max_temp = _daily_temperatures(forecast_items, target_date)
    temperature = forecast_temp if forecast_temp is not None else observed_temp
    min_temp = min(min_temp if min_temp is not None else temperature, temperature)
    max_temp = max(max_temp if max_temp is not None else temperature, temperature)
    condition = _condition_from_kma(sky, precipitation_type)
    apparent = _apparent_temperature(temperature, humidity, wind_speed_kmh)
    recommendation, items = _outfit(
        temperature=temperature,
        apparent=apparent,
        min_temp=min_temp,
        max_temp=max_temp,
        condition=condition,
        precipitation_probability=precipitation_probability,
        wind_speed_kmh=wind_speed_kmh,
    )
    label_text = _condition_label(condition)
    rain_text = (
        f"강수확률 {round(precipitation_probability)}%라 우산을 챙기는 편이 안전합니다."
        if "umbrella" in items
        else "큰 비 걱정은 크지 않습니다."
    )
    summary = (
        f"{label} 기준 현재 {round(temperature)}°C, 체감 {round(apparent)}°C입니다. "
        f"{label_text}이고 낮 최고 {round(max_temp)}°C / 최저 {round(min_temp)}°C 예상입니다. {rain_text}"
    )

    # 로그 DB 적재
    end_time = time.time()
    log_feature_run(
        run_id=f"weather-{int(start_time)}",
        feature="weather",
        owner="조수빈",
        status="success",
        used_llm=False,
        latency_ms=int((end_time - start_time) * 1000),
        prompt_tokens=None,
        completion_tokens=None,
        total_tokens=None,
    )

    return {
        "owner": "조수빈",
        "feature": "weather",
        "location": location,
        "date": date,
        "summary": summary,
        "temperature_c": temperature,
        "condition": condition,
        "recommendation": recommendation,
        "items": items,
        "uses_mock": False,
    }


def get_weather_brief(location: str, date: str) -> dict:
    # 팀 계약상 반환 dict 키는 mock 구조와 동일하게 유지합니다.
    if not _service_key():
        return _mock_weather(location, date)

    try:
        return _real_weather(location, date)
    except Exception:
        return _mock_weather(location, date)
