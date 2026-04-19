from __future__ import annotations
from datetime import datetime, timezone

from app.providers.mock_provider import load_mock
from .logging_service import get_recent_feature_runs
from .sqlite import init_db


def parse_created_at(s):
    dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt


def get_admin_summary() -> dict:
    # TODO(나정연): 이 함수 하나만 수정하면 됩니다.
    # 입력:
    # - 현재는 없음
    # 출력:
    # - 아래 dict 구조를 그대로 유지한 채 실제 로그/토큰/상태 데이터로 교체
    # 작업 방식:
    # - 지금은 mock 데이터를 읽지만, 나중에는 실행 로그나 추정 토큰 계산으로 바꾸면 됩니다.
    # - 즉, 먼저 src/jarvis/data/mocks/admin.json을 기준으로 화면/응답을 완성해야 합니다.
    # - 나중에 실제 데이터가 생기면 아래 항목으로 교체하면 됩니다:
    #   - 기능별 실행 로그
    #   - 응답 시간
    #   - 토큰 사용량 또는 추정치
    #   - 에이전트 흐름 노드/엣지
    # DB 초기화는 FastAPI startup 이벤트에서 1회만 호출하도록 변경됨

    logs = get_recent_feature_runs(limit=100)
    if not logs:
        print("No logs found, falling back to mock data for admin summary.")  # 디버깅용 출력
        # fallback to mock
        data = load_mock("admin")
        # metrics가 dict면 list로 변환, 아니면 그대로 사용
        metrics = data["metrics"]
        if isinstance(metrics, dict):
            metrics = list(metrics.values())
        return {
            "owner": "나정연",
            "feature": "admin",
            "summary": data["summary"],
            "top_token_feature": data["top_token_feature"],
            "metrics": metrics,
            "flow_nodes": data["flow_nodes"],
            "flow_edges": data["flow_edges"],
            "uses_mock": True,
        }

    # 24시간 내 로그만 필터링
    now = datetime.now(timezone.utc)
    logs_24h = [
        l for l in logs
        if "created_at" in l and
           isinstance(l["created_at"], str) and
           (now - parse_created_at(l["created_at"])).total_seconds() <= 86400
    ]

    # 기능별 집계
    feature_stats = {}
    for l in logs_24h:
        f = l["feature"]
        if f not in feature_stats:
            feature_stats[f] = {
                "count": 0,
                "token_sum": 0,
                "latency_sum": 0,
                "owner": l.get("owner", ""),
                "statuses": [],
            }
        feature_stats[f]["count"] += 1
        feature_stats[f]["token_sum"] += l.get("total_tokens", 0)
        feature_stats[f]["latency_sum"] += l.get("latency_ms", 0)
        feature_stats[f]["statuses"].append((l.get("created_at", ""), l.get("status", "unknown")))

    # summary 문자열 생성
    summary_parts = [
        f"{f} {v['count']}회(총 {v['token_sum']}토큰)"
        for f, v in feature_stats.items()
    ]
    summary = "최근 24시간 동안 " + ", ".join(summary_parts)

    # top_token_feature 계산
    top_token_feature = None
    top_token_amount = 0
    for f, v in feature_stats.items():
        if v["token_sum"] > top_token_amount:
            top_token_feature = f
            top_token_amount = v["token_sum"]

    # metrics 생성
    metrics = []
    for f, v in feature_stats.items():
        # 가장 최근 실행의 status
        recent_status = sorted(v["statuses"], reverse=True)[0][1] if v["statuses"] else "unknown"
        metrics.append({
            "feature": f,
            "owner": v["owner"],
            "token_estimate": v["token_sum"],
            "latency_ms": int(v["latency_sum"] / v["count"]) if v["count"] else 0,
            "status": recent_status,
        })

    # flow 데이터는 mock fallback
    data = load_mock("admin")
    return {
        "owner": "나정연",
        "feature": "admin",
        "summary": summary,
        "top_token_feature": f"{top_token_feature} ({top_token_amount}토큰)" if top_token_feature else None,
        "metrics": metrics,
        "flow_nodes": data["flow_nodes"],
        "flow_edges": data["flow_edges"],
        "uses_mock": False,
    }
