import { API_BASE_URL } from "./config";
import type {
  AgentInterpretRequest,
  AgentInterpretResponse,
  ApiErrorEnvelope,
  CalendarAuditResponse,
  CalendarConflictsResponse,
  CalendarDetailResponse,
  CalendarEventsResponse,
  CalendarListResponse,
  CalendarOperationListResponse,
  CalendarOperationProposal,
  CalendarOperationRejectRequest,
  CalendarOperationResult,
  CalendarSummaryResponse,
  FinalBriefing,
  HealthResponse,
  QueryWindow,
  StartupGreetingResponse,
} from "./types";

export class ApiError extends Error {
  status: number;
  body?: ApiErrorEnvelope;

  constructor(status: number, body?: ApiErrorEnvelope) {
    super(body?.error.message ?? `Request failed with status ${status}`);
    this.status = status;
    this.body = body;
  }
}

function appendQuery(path: string, params: QueryWindow): string {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value) {
      search.set(key, value);
    }
  });
  const query = search.toString();
  return query ? `${path}?${query}` : path;
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init?.headers ?? {}),
    },
  });

  const text = await response.text();
  const body = text ? JSON.parse(text) : undefined;

  if (!response.ok) {
    throw new ApiError(response.status, body as ApiErrorEnvelope | undefined);
  }

  return body as T;
}

export const api = {
  health: () => request<HealthResponse>("/health"),
  calendars: () => request<CalendarListResponse>("/calendars"),
  calendarDetail: (calendarId: string) =>
    request<CalendarDetailResponse>(`/calendars/${calendarId}`),
  events: (calendarId: string, query: QueryWindow) =>
    request<CalendarEventsResponse>(
      appendQuery(`/calendars/${calendarId}/events`, query),
    ),
  conflicts: (calendarId: string, query: QueryWindow) =>
    request<CalendarConflictsResponse>(
      appendQuery(`/calendars/${calendarId}/conflicts`, query),
    ),
  summary: (calendarId: string, query: QueryWindow) =>
    request<CalendarSummaryResponse>(
      appendQuery(`/calendars/${calendarId}/summary`, query),
    ),
  proposals: () => request<CalendarOperationListResponse>("/calendar-operations"),
  proposal: (proposalId: string) =>
    request<CalendarOperationProposal>(`/calendar-operations/${proposalId}`),
  createProposal: (payload: Record<string, unknown>) =>
    request<CalendarOperationProposal>("/calendar-operations/proposals", {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  executeProposal: (proposalId: string, payload: Record<string, unknown>) =>
    request<CalendarOperationResult>(
      `/calendar-operations/${proposalId}/execute`,
      {
        method: "POST",
        body: JSON.stringify(payload),
      },
    ),
  rejectProposal: (
    proposalId: string,
    payload: CalendarOperationRejectRequest,
  ) =>
    request<CalendarOperationResult>(
      `/calendar-operations/${proposalId}/reject`,
      {
        method: "POST",
        body: JSON.stringify(payload),
      },
    ),
  audit: () => request<CalendarAuditResponse>("/calendar-operation-audit"),
  briefing: (date: string) =>
    request<FinalBriefing>("/briefings", {
      method: "POST",
      body: JSON.stringify({
        user_input: "Calendar validation briefing",
        location: "Seoul",
        date,
        user_name: "Jarvis Mobile",
      }),
    }),
  interpretCommand: (payload: AgentInterpretRequest) =>
    request<AgentInterpretResponse>("/agent/interpret", {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  startupGreeting: (payload: {
    user_name: string;
    location: string;
    date: string;
  }) =>
    request<StartupGreetingResponse>("/assistant/startup-greeting", {
      method: "POST",
      body: JSON.stringify(payload),
    }),
};
