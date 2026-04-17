import type { PresentationStep, TeamFolderInfo } from "../common";

export const oseungdamUiFolder: TeamFolderInfo = {
  folder: "apps/web/team/oseungdam-ui",
  ownerName: "오승담",
  role: "메인 UI + 발표 화면",
  receives: ["브리핑 결과", "팀 폴더 정보", "발표 흐름"],
  returns: ["홈 화면", "브리핑 화면", "발표용 시각 흐름"],
  envKeys: []
};

export const homeIntro = {
  eyebrow: "Person Folder Structure",
  title: "사람별 폴더가 직접 주고받는 AI 비서 구조",
  description:
    "복잡한 계층 대신 각 사람 폴더가 자기 입력을 받아 결과를 만들고, 배민규 폴더가 그 결과를 모아 아침 브리핑으로 합칩니다."
};

export const demoPresentationPlan: PresentationStep[] = [
  {
    title: "문장 하나로 아침 브리핑 요청",
    description: "배민규 폴더가 요청을 받아 필요한 사람 폴더로 일을 분배합니다.",
    owner: "배민규"
  },
  {
    title: "날씨 + 옷 추천 생성",
    description: "조수빈 폴더가 위치를 입력받아 외출용 날씨 문장을 만듭니다.",
    owner: "조수빈"
  },
  {
    title: "오늘 일정 요약",
    description: "김재희 폴더가 날짜를 입력받아 일정 브리핑을 만듭니다.",
    owner: "김재희"
  },
  {
    title: "슬랙 중요 내용 요약",
    description: "문이현 폴더가 대화 맥락과 액션 아이템을 정리합니다.",
    owner: "문이현"
  },
  {
    title: "Admin에서 비용과 흐름 확인",
    description: "나정연 폴더가 토큰과 흐름 정보를 Admin 화면용으로 정리합니다.",
    owner: "나정연"
  }
];

export const apiRouteNotes = [
  {
    route: "/api/briefing",
    description: "브리핑 생성용 GET/POST 엔드포인트"
  },
  {
    route: "/api/admin/summary",
    description: "Admin용 토큰, 흐름, 폴더 정보 엔드포인트"
  },
  {
    route: "/api/health",
    description: "mock/live 상태 확인용 엔드포인트"
  }
];
