from __future__ import annotations
from collections import defaultdict

from app.providers.mock_provider import load_mock

from ..infrastructure.logging_service import get_recent_feature_runs
from ..infrastructure.sqlite import init_db


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
    # DB 초기화(앱 시작 시 1회만 호출해도 됨) -> FastAPI startup 이벤트에서 호출하도록 변경 가능
    init_db()

    logs = get_recent_feature_runs(limit=100)
    if not logs:
        print("No logs found, falling back to mock data for admin summary.")  # 디버깅용 출력
        # fallback to mock
        data = load_mock("admin")
        return {
            "owner": "나정연",
            "feature": "admin",
            "summary": data["summary"],
            "top_token_feature": data["top_token_feature"],
            "metrics": data["metrics"],
            "flow_nodes": data["flow_nodes"],
            "flow_edges": data["flow_edges"],
            "uses_mock": True,
        }

    # 집계: 예시(실제 요구에 맞게 수정 가능)
    owner = logs[0]["owner"] if logs else "나정연"
    feature = logs[0]["feature"] if logs else "admin"
    summary = f"최근 {len(logs)}회 실행, 총 토큰: {sum(l['total_tokens'] for l in logs)}"
    
    # 토큰 사용량이 가장 많은 feature
    feature_token = defaultdict(int)
    for l in logs:
        feature_token[l["feature"]] += l["total_tokens"]
    top_token_feature = max(feature_token.items(), key=lambda x: x[1])[0] if feature_token else None
    
    # metrics: feature별 토큰 합계, 평균 latency 등
    metrics = {}
    for f in set(l["feature"] for l in logs):
        f_logs = [l for l in logs if l["feature"] == f]
        metrics[f] = {
            "count": len(f_logs),
            "total_tokens": sum(l["total_tokens"] for l in f_logs),
            "avg_latency_ms": int(sum(l["latency_ms"] for l in f_logs) / len(f_logs)),
        }

    # flow 데이터는 mock fallback
    data = load_mock("admin")
    return {
        "owner": owner,
        "feature": feature,
        "summary": summary,
        "top_token_feature": top_token_feature,
        "metrics": metrics,
        "flow_nodes": data["flow_nodes"],
        "flow_edges": data["flow_edges"],
        "uses_mock": False,
    }
