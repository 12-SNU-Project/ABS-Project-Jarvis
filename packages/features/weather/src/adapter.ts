import { isMockMode } from "@jarvis/shared";
import type { WeatherApiPayload } from "./types";
import { mockWeatherPayload } from "./mock";

export interface WeatherClient {
  getCurrentWeather: (input: {
    location: string;
    date: string;
  }) => Promise<WeatherApiPayload>;
}

export function createMockWeatherClient(): WeatherClient {
  return {
    async getCurrentWeather({ location }) {
      return {
        ...mockWeatherPayload,
        location
      };
    }
  };
}

function createLiveWeatherClient(): WeatherClient {
  return {
    async getCurrentWeather(_input) {
      throw new Error(
        "Live weather client is not implemented yet. Update packages/features/weather/src/adapter.ts."
      );
    }
  };
}

export function getWeatherClient() {
  return isMockMode() ? createMockWeatherClient() : createLiveWeatherClient();
}
