import type { FeatureDescriptor, TokenUsageMetric } from "@jarvis/shared";

export const calendarFeature: FeatureDescriptor = {
  key: "calendar",
  name: "일정 브리핑",
  description: "오늘 일정과 중요 이벤트를 읽어 아침 브리핑으로 요약합니다.",
  ownerArea: "Calendar",
  integrationStatus: "mock-ready",
  envKeys: [
    "GOOGLE_CLIENT_ID",
    "GOOGLE_CLIENT_SECRET",
    "GOOGLE_REFRESH_TOKEN",
    "DEFAULT_BRIEFING_DATE"
  ]
};

export const calendarTokenMetric: TokenUsageMetric = {
  featureKey: "calendar",
  featureName: calendarFeature.name,
  totalTokens: 1840,
  promptTokens: 1020,
  completionTokens: 820
};
