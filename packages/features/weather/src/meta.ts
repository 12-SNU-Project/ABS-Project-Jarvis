import type { FeatureDescriptor, TokenUsageMetric } from "@jarvis/shared";

export const weatherFeature: FeatureDescriptor = {
  key: "weather",
  name: "날씨 + 옷 추천",
  description: "위치 기반 날씨를 읽고 외출용 옷차림을 추천합니다.",
  ownerArea: "Weather",
  integrationStatus: "mock-ready",
  envKeys: ["WEATHER_API_KEY", "DEFAULT_LOCATION"]
};

export const weatherTokenMetric: TokenUsageMetric = {
  featureKey: "weather",
  featureName: weatherFeature.name,
  totalTokens: 1320,
  promptTokens: 780,
  completionTokens: 540
};
