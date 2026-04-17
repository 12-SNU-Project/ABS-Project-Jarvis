import type { AdminSummary, TeamFolderInfo } from "../common";
import { buildDefaultInput } from "../common";
import { josubinWeatherFolder, josubinWeatherTokens } from "../josubin-weather";
import { kimjaeheeCalendarFolder, kimjaeheeCalendarTokens } from "../kimjaehee-calendar";
import { moonihyeonSlackFolder, moonihyeonSlackTokens } from "../moonihyeon-slack";
import { baemingyuOrchestratorFolder } from "../baemingyu-orchestrator";
import { oseungdamUiFolder } from "../oseungdam-ui";

export const najeongyeonAdminFolder: TeamFolderInfo = {
  folder: "apps/web/team/najeongyeon-admin",
  ownerName: "나정연",
  role: "Admin 대시보드",
  receives: ["토큰 사용량", "실행 로그", "폴더 흐름 정보"],
  returns: ["Admin 화면 데이터", "오너십 표", "흐름 그래프 데이터"],
  envKeys: []
};

export async function buildNajeongyeonAdminSummary(): Promise<AdminSummary> {
  const sampleInput = buildDefaultInput();

  return {
    generatedAt: new Date().toISOString(),
    tokenUsage: [
      josubinWeatherTokens,
      kimjaeheeCalendarTokens,
      moonihyeonSlackTokens
    ],
    recentRuns: [
      {
        ownerName: baemingyuOrchestratorFolder.ownerName,
        role: baemingyuOrchestratorFolder.role,
        status: "success",
        durationMs: 2100,
        summary: `입력 "${sampleInput.userInput}"를 받아 날씨, 일정, 슬랙 폴더로 작업을 분배했습니다.`
      },
      {
        ownerName: josubinWeatherFolder.ownerName,
        role: josubinWeatherFolder.role,
        status: "success",
        durationMs: 620,
        summary: "위치와 날짜를 받아 날씨와 옷 추천 문장을 만들었습니다."
      },
      {
        ownerName: kimjaeheeCalendarFolder.ownerName,
        role: kimjaeheeCalendarFolder.role,
        status: "success",
        durationMs: 710,
        summary: "날짜를 받아 오늘 일정 개요를 정리했습니다."
      },
      {
        ownerName: moonihyeonSlackFolder.ownerName,
        role: moonihyeonSlackFolder.role,
        status: "success",
        durationMs: 840,
        summary: "사용자 요청과 날짜를 받아 슬랙 요약과 액션 아이템을 만들었습니다."
      }
    ],
    flow: [
      {
        from: baemingyuOrchestratorFolder.ownerName,
        to: josubinWeatherFolder.ownerName
      },
      {
        from: baemingyuOrchestratorFolder.ownerName,
        to: kimjaeheeCalendarFolder.ownerName
      },
      {
        from: baemingyuOrchestratorFolder.ownerName,
        to: moonihyeonSlackFolder.ownerName
      },
      {
        from: baemingyuOrchestratorFolder.ownerName,
        to: najeongyeonAdminFolder.ownerName
      },
      {
        from: baemingyuOrchestratorFolder.ownerName,
        to: oseungdamUiFolder.ownerName
      }
    ],
    folders: [
      baemingyuOrchestratorFolder,
      oseungdamUiFolder,
      najeongyeonAdminFolder,
      josubinWeatherFolder,
      kimjaeheeCalendarFolder,
      moonihyeonSlackFolder
    ],
    notes: [
      "지금 구조의 핵심은 사람 폴더끼리 직접 주고받는 것입니다.",
      "실제 API 연결은 각 사람 폴더의 index.ts 안에서 구현하면 됩니다.",
      "Admin은 사람별 입력/출력과 토큰 사용량을 같이 보여주는 방향이 발표에 유리합니다."
    ]
  };
}
