import type { UserContext, WeatherRecommendation } from "@jarvis/shared";
import type { WeatherClient } from "./adapter";
import { getWeatherClient } from "./adapter";

function buildClothingAdvice(temperatureC: number, precipitationChance: number) {
  if (temperatureC <= 8) {
    return "코트나 경량 패딩, 긴 바지를 추천합니다.";
  }

  if (precipitationChance >= 50) {
    return "얇은 겉옷과 우산을 챙기고, 방수 신발이면 더 좋습니다.";
  }

  if (temperatureC <= 18) {
    return "가디건이나 얇은 재킷 정도가 적당합니다.";
  }

  return "반팔 위에 가벼운 아우터 정도면 무난합니다.";
}

export async function getWeatherRecommendation(
  context: UserContext,
  client: WeatherClient = getWeatherClient()
): Promise<WeatherRecommendation> {
  const payload = await client.getCurrentWeather({
    location: context.location,
    date: context.date
  });

  return {
    location: payload.location,
    temperatureC: payload.temperatureC,
    condition: payload.condition,
    clothingAdvice: buildClothingAdvice(
      payload.temperatureC,
      payload.precipitationChance
    )
  };
}
