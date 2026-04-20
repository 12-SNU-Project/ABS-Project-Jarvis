import pytest
from app.services.support.admin import get_admin_summary

def test_admin_summary_with_mock(monkeypatch):
    # get_recent_feature_runs이 빈 리스트 반환하도록 monkeypatch
    monkeypatch.setattr("app.services.support.admin.get_recent_feature_runs", lambda limit: [])
    result = get_admin_summary()
    assert result["uses_mock"] is True
    assert "summary" in result
    assert isinstance(result["metrics"], list)

def test_admin_summary_with_logs(monkeypatch):
    # 가짜 로그 데이터로 monkeypatch
    fake_logs = [
        {
            "feature": "calendar",
            "owner": "김재희",
            "created_at": "2026-04-19T10:00:00+00:00",
            "total_tokens": 100,
            "latency_ms": 200,
            "status": "success",
        },
        {
            "feature": "calendar",
            "owner": "김재희",
            "created_at": "2026-04-19T11:00:00+00:00",
            "total_tokens": 50,
            "latency_ms": 100,
            "status": "success",
        },
    ]
    monkeypatch.setattr("app.services.support.admin.get_recent_feature_runs", lambda limit: fake_logs)
    result = get_admin_summary()
    assert result["uses_mock"] is False
    assert "calendar" in [m["feature"] for m in result["metrics"]]
    assert result["metrics"][0]["token_estimate"] == 150
