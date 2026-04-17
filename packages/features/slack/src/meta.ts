import type { FeatureDescriptor, TokenUsageMetric } from "@jarvis/shared";

export const slackFeature: FeatureDescriptor = {
  key: "slack",
  name: "슬랙 요약",
  description: "중요 채널과 스레드의 맥락을 요약하고 액션 아이템을 추출합니다.",
  ownerArea: "Slack",
  integrationStatus: "mock-ready",
  envKeys: ["SLACK_BOT_TOKEN", "SLACK_TEAM_ID", "OPENAI_API_KEY", "OPENAI_MODEL"]
};

export const slackTokenMetric: TokenUsageMetric = {
  featureKey: "slack",
  featureName: slackFeature.name,
  totalTokens: 2260,
  promptTokens: 1410,
  completionTokens: 850
};
