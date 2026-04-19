export type Role = "assistant" | "user" | "system";

export interface ErrorDetail {
  field?: string | null;
  message: string;
  code: string;
}

export interface ApiErrorEnvelope {
  error: {
    code: string;
    message: string;
    details: ErrorDetail[];
  };
}

export interface HealthResponse {
  status: string;
  use_mocks: boolean;
  model: string;
}

export interface CalendarInfo {
  id: string;
  name: string;
  timezone: string;
  is_primary: boolean;
  uses_mock: boolean;
}

export interface CalendarEvent {
  id: string;
  calendar_id: string;
  title: string;
  start: string;
  end: string;
  description?: string | null;
  location?: string | null;
  priority: string;
  all_day: boolean;
  recurring: boolean;
  recurrence_rule?: string | null;
  recurrence_interval_days?: number | null;
  recurrence_count?: number | null;
  series_id?: string | null;
}

export interface CalendarConflict {
  type: string;
  message: string;
  severity: string;
  event_ids: string[];
}

export interface CalendarEventsResponse {
  owner: string;
  feature: string;
  uses_mock: boolean;
  calendar: CalendarInfo;
  events: CalendarEvent[];
}

export interface CalendarConflictsResponse {
  owner: string;
  feature: string;
  uses_mock: boolean;
  calendar: CalendarInfo;
  conflicts: CalendarConflict[];
}

export interface CalendarSummaryResponse {
  owner: string;
  feature: string;
  uses_mock: boolean;
  calendar: CalendarInfo;
  date: string;
  summary: string;
  events: CalendarEvent[];
  conflicts: CalendarConflict[];
}

export interface CalendarListResponse {
  owner: string;
  feature: string;
  uses_mock: boolean;
  calendars: CalendarInfo[];
}

export interface CalendarDetailResponse {
  owner: string;
  feature: string;
  uses_mock: boolean;
  calendar: CalendarInfo;
}

export interface CalendarOperationProposal {
  proposal_id: string;
  operation_type: string;
  status: string;
  actor: string;
  target_summary: string;
  calendar_id?: string | null;
  event_id?: string | null;
  recurring_scope?: string | null;
  requires_confirmation: boolean;
  warnings: string[];
  before_state?: Record<string, unknown> | null;
  after_state?: Record<string, unknown> | null;
  snapshot_hash: string;
  created_at: string;
  executed_at?: string | null;
  error_message?: string | null;
}

export interface CalendarOperationResult {
  proposal_id: string;
  operation_type: string;
  status: string;
  target_summary: string;
  snapshot_hash: string;
  executed_at: string;
}

export interface CalendarOperationListResponse {
  owner: string;
  feature: string;
  uses_mock: boolean;
  operations: CalendarOperationProposal[];
}

export interface CalendarAuditRecord {
  audit_id: string;
  proposal_id: string;
  operation_type: string;
  actor: string;
  calendar_id?: string | null;
  event_id?: string | null;
  recurring_scope?: string | null;
  warnings: string[];
  before_state?: Record<string, unknown> | null;
  after_state?: Record<string, unknown> | null;
  result_status: string;
  error_message?: string | null;
  recorded_at: string;
}

export interface CalendarAuditResponse {
  owner: string;
  feature: string;
  uses_mock: boolean;
  records: CalendarAuditRecord[];
}

export interface CalendarBrief {
  owner: string;
  feature: string;
  uses_mock: boolean;
  calendar_id: string;
  date: string;
  summary: string;
  events: CalendarEvent[];
  conflicts: CalendarConflict[];
}

export interface FinalBriefing {
  headline: string;
  generated_for: string;
  user_input: string;
  final_summary: string;
  calendar: CalendarBrief;
}

export interface QueryWindow {
  date?: string;
  start_date?: string;
  end_date?: string;
}

export interface AgentInterpretRequest {
  input: string;
  date: string;
  calendar_id: string;
  latest_proposal_id?: string;
}

export interface AgentInterpretResponse {
  owner: string;
  feature: string;
  uses_mock: boolean;
  status: "interpreted" | "clarify";
  source: string;
  command?: string | null;
  explanation: string;
}

export interface CalendarOperationRejectRequest {
  proposal_id: string;
  reason?: string;
}

export type AssistantServiceStatus = {
  service: string;
  status: string;
  message: string;
};

export type StartupGreetingResponse = {
  owner: string;
  feature: string;
  uses_mock: boolean;
  date: string;
  location: string;
  source: string;
  greeting: string;
  services: AssistantServiceStatus[];
};

export interface ChatMessage {
  id: string;
  role: Role;
  text: string;
}
