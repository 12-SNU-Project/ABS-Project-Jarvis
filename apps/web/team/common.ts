export type BriefingInput = {
  userInput: string;
  location: string;
  date: string;
};

export type BriefingSection = {
  key: "weather" | "calendar" | "slack";
  ownerName: string;
  title: string;
  content: string;
};

export type MorningBriefing = {
  headline: string;
  summary: string;
  sections: BriefingSection[];
  followUps: string[];
};

export type TokenUsage = {
  key: string;
  label: string;
  totalTokens: number;
  promptTokens: number;
  completionTokens: number;
};

export type TeamFolderInfo = {
  folder: string;
  ownerName: string;
  role: string;
  receives: string[];
  returns: string[];
  envKeys: string[];
};

export type AdminSummary = {
  generatedAt: string;
  tokenUsage: TokenUsage[];
  recentRuns: Array<{
    ownerName: string;
    role: string;
    status: "success" | "error";
    durationMs: number;
    summary: string;
  }>;
  flow: Array<{
    from: string;
    to: string;
  }>;
  folders: TeamFolderInfo[];
  notes: string[];
};

export type PresentationStep = {
  title: string;
  description: string;
  owner: string;
};

export function isMockMode() {
  return process.env.JARVIS_USE_MOCKS !== "false";
}

export function buildDefaultInput(
  overrides: Partial<BriefingInput> = {}
): BriefingInput {
  return {
    userInput: "오늘 아침 브리핑 준비해줘",
    location: process.env.DEFAULT_LOCATION ?? "Seoul",
    date: process.env.DEFAULT_BRIEFING_DATE ?? "2026-04-17",
    ...overrides
  };
}
