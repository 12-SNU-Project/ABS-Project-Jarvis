export type FeatureKey = "weather" | "calendar" | "slack" | "presentation";

export type AgentStatus = "idle" | "running" | "success" | "error";

export type IntegrationStatus = "mock-ready" | "live-todo" | "integrated";

export interface UserContext {
  userInput: string;
  location: string;
  date: string;
}

export interface BriefingSection {
  agentKey: FeatureKey | "orchestrator";
  title: string;
  content: string;
}

export interface BriefingResult {
  headline: string;
  summary: string;
  sections: BriefingSection[];
  followUps: string[];
}

export interface AgentRun {
  runId: string;
  agentName: string;
  agentKey: string;
  status: AgentStatus;
  durationMs: number;
  summary: string;
}

export interface TokenUsageMetric {
  featureKey: string;
  featureName: string;
  totalTokens: number;
  promptTokens: number;
  completionTokens: number;
}

export interface WeatherRecommendation {
  location: string;
  temperatureC: number;
  condition: string;
  clothingAdvice: string;
}

export interface CalendarBrief {
  date: string;
  summary: string;
  events: Array<{
    title: string;
    start: string;
    end: string;
    importance: "low" | "medium" | "high";
  }>;
}

export interface SlackDigest {
  workspace: string;
  summary: string;
  highlights: string[];
  actionItems: string[];
}

export interface PresentationStep {
  title: string;
  description: string;
  owner: string;
}

export interface FeatureDescriptor {
  key: FeatureKey;
  name: string;
  description: string;
  ownerArea: string;
  integrationStatus: IntegrationStatus;
  envKeys: string[];
}

export interface AgentGraphNode {
  agentKey: string;
  label: string;
  kind: "input" | "feature" | "system" | "output";
  dependsOn: string[];
}

export interface AdminSnapshot {
  generatedAt: string;
  tokenMetrics: TokenUsageMetric[];
  recentRuns: AgentRun[];
  graph: AgentGraphNode[];
  features: FeatureDescriptor[];
  notes: string[];
}
