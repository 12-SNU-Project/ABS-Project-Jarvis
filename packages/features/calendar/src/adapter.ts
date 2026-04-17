import { isMockMode } from "@jarvis/shared";
import type { CalendarBrief } from "@jarvis/shared";
import { mockCalendarBrief } from "./mock";

export interface CalendarClient {
  getDailyBrief: (input: { date: string }) => Promise<CalendarBrief>;
}

export function createMockCalendarClient(): CalendarClient {
  return {
    async getDailyBrief({ date }) {
      return {
        ...mockCalendarBrief,
        date
      };
    }
  };
}

function createLiveCalendarClient(): CalendarClient {
  return {
    async getDailyBrief(_input) {
      throw new Error(
        "Live calendar client is not implemented yet. Update packages/features/calendar/src/adapter.ts."
      );
    }
  };
}

export function getCalendarClient() {
  return isMockMode() ? createMockCalendarClient() : createLiveCalendarClient();
}
