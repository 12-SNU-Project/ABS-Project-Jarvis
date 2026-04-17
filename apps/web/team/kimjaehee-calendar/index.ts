import type { BriefingInput, BriefingSection, TeamFolderInfo, TokenUsage } from "../common";
import { isMockMode } from "../common";

const mockCalendar = {
  summary: "오전에는 회의가 집중되어 있고, 오후에는 비교적 여유가 있습니다.",
  events: [
    {
      title: "팀 스탠드업",
      start: "09:30",
      end: "10:00",
      importance: "high"
    },
    {
      title: "프로젝트 기능 점검",
      start: "13:00",
      end: "14:00",
      importance: "medium"
    }
  ]
};

export const kimjaeheeCalendarFolder: TeamFolderInfo = {
  folder: "apps/web/team/kimjaehee-calendar",
  ownerName: "김재희",
  role: "일정 브리핑",
  receives: ["date"],
  returns: ["일정 요약", "중요 이벤트 목록", "토큰 사용량"],
  envKeys: [
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET",
    "GOOGLE_REFRESH_TOKEN",
    "DEFAULT_BRIEFING_DATE"
  ]
};

export const kimjaeheeCalendarTokens: TokenUsage = {
  key: "calendar",
  label: "일정 브리핑",
  totalTokens: 1840,
  promptTokens: 1020,
  completionTokens: 820
};

async function readLiveCalendar(
  _input: BriefingInput
): Promise<typeof mockCalendar> {
  throw new Error(
    "김재희 폴더에서 실제 Google Calendar 연결이 아직 없습니다. apps/web/team/kimjaehee-calendar/index.ts를 구현해주세요."
  );
}

export async function runKimjaeheeCalendarFolder(
  input: BriefingInput
): Promise<BriefingSection> {
  const calendar = isMockMode() ? mockCalendar : await readLiveCalendar(input);

  return {
    key: "calendar",
    ownerName: kimjaeheeCalendarFolder.ownerName,
    title: "일정 브리핑",
    content: `${calendar.summary} 오늘 주요 일정은 ${calendar.events.length}개입니다.`
  };
}
