import type { SlackDigest } from "@jarvis/shared";

export const mockSlackDigest: SlackDigest = {
  workspace: "team-workspace",
  summary: "오늘 아침에는 프로젝트 범위 확정과 슬랙 요약 기능 논의가 중심이었습니다.",
  highlights: [
    "카카오톡 대신 슬랙 요약으로 범위를 조정하는 방향에 공감대 형성",
    "메인 에이전트가 날씨, 일정, 슬랙 요약을 묶는 방식이 유력",
    "Admin은 토큰 사용량 시각화 정도만 있어도 충분하다는 의견"
  ],
  actionItems: [
    "슬랙 API 연결 가능 여부 확인",
    "에이전트별 역할과 폴더 구조 확정",
    "토요일까지 각 기능 프로토타입 작성"
  ]
};
