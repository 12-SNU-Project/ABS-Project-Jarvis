import type { BriefingInput, BriefingSection, TeamFolderInfo, TokenUsage } from "../common";
import { isMockMode } from "../common";

const mockSlack = {
  summary: "오늘 아침에는 프로젝트 범위 확정과 슬랙 요약 기능 논의가 중심이었습니다.",
  actionItems: [
    "슬랙 API 연결 가능 여부 확인",
    "에이전트별 역할과 폴더 구조 확정",
    "토요일까지 각 기능 프로토타입 작성"
  ]
};

export const moonihyeonSlackFolder: TeamFolderInfo = {
  folder: "apps/web/team/moonihyeon-slack",
  ownerName: "문이현",
  role: "슬랙 요약",
  receives: ["userInput", "date"],
  returns: ["슬랙 요약", "액션 아이템", "토큰 사용량"],
  envKeys: ["SLACK_BOT_TOKEN", "SLACK_TEAM_ID", "OPENAI_API_KEY", "OPENAI_MODEL"]
};

export const moonihyeonSlackTokens: TokenUsage = {
  key: "slack",
  label: "슬랙 요약",
  totalTokens: 2260,
  promptTokens: 1410,
  completionTokens: 850
};

async function readLiveSlack(
  _input: BriefingInput
): Promise<typeof mockSlack> {
  throw new Error(
    "문이현 폴더에서 실제 Slack + 생성형 AI 연결이 아직 없습니다. apps/web/team/moonihyeon-slack/index.ts를 구현해주세요."
  );
}

export async function runMoonihyeonSlackFolder(
  input: BriefingInput
): Promise<BriefingSection> {
  const slack = isMockMode() ? mockSlack : await readLiveSlack(input);

  return {
    key: "slack",
    ownerName: moonihyeonSlackFolder.ownerName,
    title: "슬랙 요약",
    content: `${slack.summary} 지금 확인할 액션 아이템은 ${slack.actionItems.length}개입니다.`
  };
}
