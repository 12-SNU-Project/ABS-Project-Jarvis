from __future__ import annotations

from app.providers.mock_provider import load_mock


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
