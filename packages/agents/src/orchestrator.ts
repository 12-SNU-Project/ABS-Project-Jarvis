import type { BriefingResult, UserContext } from "@jarvis/shared";
import { getCalendarBrief } from "@jarvis/feature-calendar";
import { getSlackDigest } from "@jarvis/feature-slack";
import { getWeatherRecommendation } from "@jarvis/feature-weather";
import type { AgentDependencies, Orchestrator } from "./contracts";

const defaultDependencies: AgentDependencies = {
  weather: getWeatherRecommendation,
  calendar: getCalendarBrief,
  slack: getSlackDigest
};

export function createOrchestrator(
  dependencies: AgentDependencies = defaultDependencies
): Orchestrator {
  return {
    async runMorningBriefing(context: UserContext): Promise<BriefingResult> {
      const [weather, calendar, slack] = await Promise.all([
        dependencies.weather(context),
        dependencies.calendar(context),
        dependencies.slack(context)
      ]);

      return {
        headline: "오늘 아침 브리핑이 준비됐어요.",
        summary:
          "메인 에이전트가 날씨, 일정, 슬랙 요약을 합쳐 출근 전 한 번에 확인할 수 있는 브리핑을 만들었습니다.",
        sections: [
          {
            agentKey: "weather",
            title: "날씨 + 옷 추천",
            content: `${weather.location} 기준 ${weather.temperatureC}도, ${weather.condition}. ${weather.clothingAdvice}`
          },
          {
            agentKey: "calendar",
            title: "일정 브리핑",
            content: `${calendar.summary} 오늘 주요 일정은 ${calendar.events.length}개입니다.`
          },
          {
            agentKey: "slack",
            title: "슬랙 요약",
            content: `${slack.summary} 지금 확인할 액션 아이템은 ${slack.actionItems.length}개입니다.`
          }
        ],
        followUps: [
          "실제 LLM 호출 시 토큰 사용량을 AgentRun 로그에 함께 적재하기",
          "스케줄러 또는 음성 입력으로 runMorningBriefing 트리거 연결하기",
          "브리핑 결과를 슬랙 DM 또는 웹 위젯으로 전달하기"
        ]
      };
    }
  };
}

export const orchestrator = createOrchestrator();

export async function runMorningBriefing(context: UserContext) {
  return orchestrator.runMorningBriefing(context);
}
