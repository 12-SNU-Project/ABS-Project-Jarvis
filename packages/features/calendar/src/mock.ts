import type { CalendarBrief } from "@jarvis/shared";

export const mockCalendarBrief: CalendarBrief = {
  date: "2026-04-17",
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
