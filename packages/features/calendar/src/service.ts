import type { CalendarBrief, UserContext } from "@jarvis/shared";
import type { CalendarClient } from "./adapter";
import { getCalendarClient } from "./adapter";

export async function getCalendarBrief(
  context: UserContext,
  client: CalendarClient = getCalendarClient()
): Promise<CalendarBrief> {
  return client.getDailyBrief({
    date: context.date
  });
}
