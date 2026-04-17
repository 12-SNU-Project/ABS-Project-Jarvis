import type { BriefingInput, MorningBriefing, TeamFolderInfo } from "../common";
import { buildDefaultInput } from "../common";
import { josubinWeatherFolder, runJosubinWeatherFolder } from "../josubin-weather";
import { kimjaeheeCalendarFolder, runKimjaeheeCalendarFolder } from "../kimjaehee-calendar";
import { moonihyeonSlackFolder, runMoonihyeonSlackFolder } from "../moonihyeon-slack";
import { najeongyeonAdminFolder } from "../najeongyeon-admin";
import { oseungdamUiFolder } from "../oseungdam-ui";

export const baemingyuOrchestratorFolder: TeamFolderInfo = {
  folder: "apps/web/team/baemingyu-orchestrator",
  ownerName: "배민규",
  role: "오케스트레이터",
  receives: ["userInput", "location", "date"],
  returns: ["최종 브리핑", "사람 폴더 연결 흐름"],
  envKeys: ["DEFAULT_LOCATION", "DEFAULT_BRIEFING_DATE"]
};

export function listTeamFolders() {
  return [
    baemingyuOrchestratorFolder,
    oseungdamUiFolder,
    najeongyeonAdminFolder,
    josubinWeatherFolder,
    kimjaeheeCalendarFolder,
    moonihyeonSlackFolder
  ];
}

export async function runMorningBriefing(
  overrides: Partial<BriefingInput> = {}
): Promise<MorningBriefing> {
  const input = buildDefaultInput(overrides);
  const [weather, calendar, slack] = await Promise.all([
    runJosubinWeatherFolder(input),
    runKimjaeheeCalendarFolder(input),
    runMoonihyeonSlackFolder(input)
  ]);

  return {
    headline: "오늘 아침 브리핑이 준비됐어요.",
    summary:
      "배민규 폴더가 조수빈, 김재희, 문이현 폴더의 결과를 모아 한 번에 확인할 수 있는 브리핑으로 합쳤습니다.",
    sections: [weather, calendar, slack],
    followUps: [
      "각 사람 폴더에서 mock 대신 실제 API 연결 붙이기",
      "실행 결과를 슬랙 DM이나 위젯으로 전달하기",
      "사용자 문장에 따라 필요한 폴더만 선택해서 호출하도록 고도화하기"
    ]
  };
}
