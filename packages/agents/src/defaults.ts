import type { UserContext } from "@jarvis/shared";
import { readEnv } from "@jarvis/shared";

export const defaultUserContext: UserContext = {
  userInput: "오늘 아침 브리핑 준비해줘",
  location: readEnv("DEFAULT_LOCATION") ?? "Seoul",
  date: readEnv("DEFAULT_BRIEFING_DATE") ?? "2026-04-17"
};

export function buildUserContext(overrides: Partial<UserContext> = {}): UserContext {
  return {
    ...defaultUserContext,
    ...overrides
  };
}
