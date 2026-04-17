import type { BriefingInput, BriefingSection, TeamFolderInfo, TokenUsage } from "../common";
import { isMockMode } from "../common";

const mockWeather = {
  temperatureC: 18,
  condition: "맑음",
  precipitationChance: 10
};

export const josubinWeatherFolder: TeamFolderInfo = {
  folder: "apps/web/team/josubin-weather",
  ownerName: "조수빈",
  role: "날씨 + 옷 추천",
  receives: ["location", "date"],
  returns: ["날씨 요약 문장", "옷 추천 문장", "토큰 사용량"],
  envKeys: ["WEATHER_API_KEY", "DEFAULT_LOCATION"]
};

export const josubinWeatherTokens: TokenUsage = {
  key: "weather",
  label: "날씨 + 옷 추천",
  totalTokens: 1320,
  promptTokens: 780,
  completionTokens: 540
};

function pickClothes(temperatureC: number, precipitationChance: number) {
  if (temperatureC <= 8) {
    return "코트나 경량 패딩, 긴 바지가 잘 맞습니다.";
  }

  if (precipitationChance >= 50) {
    return "얇은 겉옷과 우산을 챙기고 방수 신발이면 더 좋습니다.";
  }

  if (temperatureC <= 18) {
    return "가디건이나 얇은 재킷 정도가 적당합니다.";
  }

  return "반팔 위에 가벼운 아우터 정도면 무난합니다.";
}

async function readLiveWeather(
  _input: BriefingInput
): Promise<typeof mockWeather> {
  throw new Error(
    "조수빈 폴더에서 실제 날씨 API를 아직 연결하지 않았습니다. apps/web/team/josubin-weather/index.ts를 구현해주세요."
  );
}

export async function runJosubinWeatherFolder(
  input: BriefingInput
): Promise<BriefingSection> {
  const weather = isMockMode() ? mockWeather : await readLiveWeather(input);

  return {
    key: "weather",
    ownerName: josubinWeatherFolder.ownerName,
    title: "날씨 + 옷 추천",
    content: `${input.location} 기준 ${weather.temperatureC}도, ${weather.condition}. ${pickClothes(
      weather.temperatureC,
      weather.precipitationChance
    )}`
  };
}
