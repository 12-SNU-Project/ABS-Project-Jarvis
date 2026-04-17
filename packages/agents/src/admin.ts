import type { AdminService } from "./contracts";
import type { AdminSnapshot, AgentRun, AgentGraphNode, FeatureDescriptor } from "@jarvis/shared";
import { calendarFeature, calendarTokenMetric } from "@jarvis/feature-calendar";
import { slackFeature, slackTokenMetric } from "@jarvis/feature-slack";
import { weatherFeature, weatherTokenMetric } from "@jarvis/feature-weather";

const features: FeatureDescriptor[] = [weatherFeature, calendarFeature, slackFeature];

const graph: AgentGraphNode[] = [
  {
    agentKey: "input",
    label: "User Input / Scheduler",
    kind: "input",
    dependsOn: []
  },
  {
    agentKey: "orchestrator",
    label: "Main Orchestrator",
    kind: "system",
    dependsOn: ["input"]
  },
  {
    agentKey: "weather",
    label: "Weather Agent",
    kind: "feature",
    dependsOn: ["orchestrator"]
  },
  {
    agentKey: "calendar",
    label: "Calendar Agent",
    kind: "feature",
    dependsOn: ["orchestrator"]
  },
  {
    agentKey: "slack",
    label: "Slack Agent",
    kind: "feature",
    dependsOn: ["orchestrator"]
  },
  {
    agentKey: "briefing",
    label: "Briefing Composer",
    kind: "output",
    dependsOn: ["weather", "calendar", "slack"]
  }
];

function buildRecentRuns(): AgentRun[] {
  return [
    {
      runId: "run_001",
      agentName: "Main Orchestrator",
      agentKey: "orchestrator",
      status: "success",
      durationMs: 2100,
      summary: "사용자 요청을 분석하고 weather, calendar, slack 기능을 병렬 호출했습니다."
    },
    {
      runId: "run_002",
      agentName: "Weather Agent",
      agentKey: "weather",
      status: "success",
      durationMs: 620,
      summary: "현재 위치 기준 기온과 강수 확률을 기반으로 옷 추천을 생성했습니다."
    },
    {
      runId: "run_003",
      agentName: "Calendar Agent",
      agentKey: "calendar",
      status: "success",
      durationMs: 710,
      summary: "오늘 일정을 가져와 중요도와 시간대 기준으로 요약했습니다."
    },
    {
      runId: "run_004",
      agentName: "Slack Agent",
      agentKey: "slack",
      status: "success",
      durationMs: 840,
      summary: "중요 채널과 스레드에서 액션 아이템을 추출했습니다."
    }
  ];
}

export const adminService: AdminService = {
  async getAdminSnapshot(): Promise<AdminSnapshot> {
    return {
      generatedAt: new Date().toISOString(),
      tokenMetrics: [weatherTokenMetric, calendarTokenMetric, slackTokenMetric],
      recentRuns: buildRecentRuns(),
      graph,
      features,
      notes: [
        "현재는 mock 모드 기준 데이터입니다.",
        "실제 API 연결은 각 feature의 adapter.ts에서 구현하면 됩니다.",
        "Admin은 토큰 소모량과 에이전트 흐름 시각화부터 먼저 완성하는 것이 안전합니다."
      ]
    };
  },
  listFeatureDescriptors() {
    return features;
  }
};

export async function getAdminSnapshot() {
  return adminService.getAdminSnapshot();
}

export function listFeatureDescriptors() {
  return adminService.listFeatureDescriptors();
}
