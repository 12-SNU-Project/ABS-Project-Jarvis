from __future__ import annotations


def test_health_sleep_route_returns_mock_summary(client) -> None:
    response = client.get("/api/v1/health/sleep")

    assert response.status_code == 200
    body = response.json()
    assert body["health_data_type"] == "com.samsung.health.sleep"
    assert body["integration_mode"] == "android_sdk_bridge"
    assert body["partnership_required"] is True
    assert len(body["planned_data_types"]) >= 1
    assert body["range_days"] == 7
    assert body["recent_nights_count"] >= 1
    assert isinstance(body["sleep_history"], list)
    assert len(body["assistant_actions"]) >= 1
    assert body["today_sleep_recommendation"]


def test_health_sleep_bridge_rejects_invalid_token(client) -> None:
    response = client.post(
        "/api/v1/health/sleep/bridge",
        headers={"X-Bridge-Token": "wrong-token"},
        json={
            "health_data_type": "com.samsung.health.sleep",
            "status": "awake",
            "items": [],
        },
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_bridge_token"


def test_health_sleep_bridge_persists_uploaded_payload(client, monkeypatch) -> None:
    monkeypatch.setenv("SAMSUNG_HEALTH_USE_MOCK", "false")

    bridge_payload = {
        "health_data_type": "com.samsung.health.sleep",
        "detected_at": "2026-04-18T07:12:00+09:00",
        "range_days": 7,
        "status": "awake",
        "items": [
            {
                "start_time": 1776440880000,
                "end_time": 1776467100000,
                "time_offset": 32400000,
                "comment": "Uploaded from Android Samsung Health bridge.",
            },
            {
                "start_time": 1776356280000,
                "end_time": 1776381600000,
                "time_offset": 32400000,
                "comment": "Previous sleep session.",
            }
        ],
    }

    ingest_response = client.post(
        "/api/v1/health/sleep/bridge",
        headers={"X-Bridge-Token": "bridge-test-token"},
        json=bridge_payload,
    )

    assert ingest_response.status_code == 200
    ingest_body = ingest_response.json()
    assert ingest_body["source"] == "samsung_health"
    assert ingest_body["uses_mock"] is False
    assert ingest_body["summary"] == "Uploaded from Android Samsung Health bridge."

    read_response = client.get("/api/v1/health/sleep")

    assert read_response.status_code == 200
    read_body = read_response.json()
    assert read_body["source"] == "samsung_health"
    assert read_body["uses_mock"] is False
    assert read_body["range_days"] == 7
    assert read_body["recent_nights_count"] == 2
    assert read_body["sleep_duration_minutes"] == 437
    assert read_body["average_sleep_duration_minutes"] == 430
    assert read_body["wake_time"] == "2026-04-18T08:05:00+09:00"
    assert read_body["sleep_debt_minutes_vs_target"] == 101
    assert len(read_body["sleep_history"]) == 2
    assert read_body["sleep_history"][0]["wake_time"] == "2026-04-18T08:05:00+09:00"
    assert read_body["today_sleep_recommendation"]
