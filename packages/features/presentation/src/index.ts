import type { PresentationStep } from "@jarvis/shared";

export const demoPresentationPlan: {
  title: string;
  steps: PresentationStep[];
} = {
  title: "Jarvis Demo Scenario",
  steps: [
    {
      title: "문장 하나로 아침 브리핑 요청",
      description: "메인 에이전트가 자연어 입력을 받아 필요한 기능을 선택합니다.",
      owner: "오케스트레이션"
    },
    {
      title: "날씨 + 옷 추천 조합",
      description: "외출 준비에 필요한 가장 직관적인 정보를 먼저 보여줍니다.",
      owner: "날씨"
    },
    {
      title: "오늘 일정과 충돌 포인트 확인",
      description: "중요 일정과 빠르게 놓치기 쉬운 시간 충돌을 전달합니다.",
      owner: "일정"
    },
    {
      title: "슬랙 중요 대화 요약",
      description: "읽지 못한 팀 대화에서 액션 아이템만 압축합니다.",
      owner: "슬랙"
    },
    {
      title: "Admin에서 토큰 소모 비교",
      description: "발표에서 기능별 비용과 흐름을 시각적으로 보여줍니다.",
      owner: "Admin"
    }
  ]
};
