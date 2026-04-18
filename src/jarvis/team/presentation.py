from __future__ import annotations

from jarvis.core.mock_loader import load_mock


def get_presentation_demo() -> dict:
    # TODO(오승담): 이 함수 하나만 수정하면 됩니다.
    # 입력:
    # - 현재는 없음
    # 출력:
    # - 아래 dict 구조를 그대로 유지한 채 발표용 카드/데모 데이터로 교체
    # 작업 방식:
    # - 지금은 mock 데이터를 읽지만, 나중에는 실제 발표 흐름이나 UI 연결 데이터로 바꾸면 됩니다.
    # - 즉, 먼저 src/jarvis/data/mocks/presentation.json을 기준으로 발표 데모를 완성해야 합니다.
    # - 나중에 실제 데이터가 생기면 아래 항목으로 교체하면 됩니다:
    #   - 발표 순서
    #   - 화면별 설명 문구
    #   - 강조하고 싶은 포인트
    #   - 데모 카드 구성
    data = load_mock("presentation")
    return {
        "owner": "오승담",
        "feature": "presentation",
        "demo_title": data["demo_title"],
        "cards": data["cards"],
        "closing_message": data["closing_message"],
        "uses_mock": True,
    }
