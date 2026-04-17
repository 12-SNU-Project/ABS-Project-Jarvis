import type {
  AdminSnapshot,
  BriefingResult,
  CalendarBrief,
  FeatureDescriptor,
  SlackDigest,
  UserContext,
  WeatherRecommendation
} from "@jarvis/shared";

export interface AgentDependencies {
  weather: (context: UserContext) => Promise<WeatherRecommendation>;
  calendar: (context: UserContext) => Promise<CalendarBrief>;
  slack: (context: UserContext) => Promise<SlackDigest>;
}

export interface Orchestrator {
  runMorningBriefing: (context: UserContext) => Promise<BriefingResult>;
}

export interface AdminService {
  getAdminSnapshot: () => Promise<AdminSnapshot>;
  listFeatureDescriptors: () => FeatureDescriptor[];
}
