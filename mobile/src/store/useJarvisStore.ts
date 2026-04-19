import { create } from "zustand";

import {
  HELP_TEXT,
  buildCreateProposalFromDraft,
  buildEventDraftPrompt,
  continuePendingEventDraft,
  inferPendingEventDraft,
  isEventDraftComplete,
  parseCommand,
  type AgentAction,
  type ParseContext,
  type PendingEventDraft,
} from "../lib/agent";
import { ApiError, api } from "../lib/api";
import type {
  CalendarAuditRecord,
  CalendarConflict,
  CalendarEvent,
  CalendarOperationProposal,
  ChatMessage,
} from "../lib/types";

type AssistantPhase = "idle" | "thinking" | "speaking" | "listening";
type ContextualReadAction = Extract<
  AgentAction,
  { kind: "showEvents" | "showConflicts" | "showSummary" | "showBriefing" }
>;
type PendingConfirmation = {
  action: AgentAction;
};

type JarvisState = {
  messages: ChatMessage[];
  draft: string;
  phase: AssistantPhase;
  hasStarted: boolean;
  isBooting: boolean;
  backendStatus: "idle" | "connected" | "degraded";
  defaultDate: string;
  defaultCalendarId: string;
  latestProposalId?: string;
  lastContextualReadAction: ContextualReadAction | null;
  pendingConfirmation: PendingConfirmation | null;
  pendingEventDraft: PendingEventDraft | null;
  setDraft: (value: string) => void;
  startAssistant: () => Promise<void>;
  submitPrompt: (prompt: string) => Promise<void>;
};

function getLocalDate(): string {
  return new Intl.DateTimeFormat("en-CA", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function shiftIsoDate(date: string, days: number): string {
  const [year, month, day] = date.split("-").map(Number);
  const shifted = new Date(Date.UTC(year, month - 1, day));
  shifted.setUTCDate(shifted.getUTCDate() + days);
  return shifted.toISOString().slice(0, 10);
}

function makeMessage(role: ChatMessage["role"], text: string): ChatMessage {
  return {
    id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    role,
    text,
  };
}

function formatApiError(error: unknown): string {
  if (error instanceof ApiError) {
    const detail = error.body?.error.details?.[0];
    const detailText = detail
      ? ` (${detail.field ?? "request"}: ${detail.message})`
      : "";
    return `${error.message}${detailText}`;
  }

  if (
    typeof error === "object" &&
    error !== null &&
    "error" in error &&
    typeof error.error === "object" &&
    error.error !== null
  ) {
    const payload = error as {
      error: {
        message?: string;
        details?: Array<{ field?: string; message?: string }>;
      };
    };
    const detail = payload.error.details?.[0];
    const detailText = detail?.message
      ? ` (${detail.field ?? "request"}: ${detail.message})`
      : "";
    return `${payload.error.message ?? "Backend request failed."}${detailText}`;
  }

  if (error instanceof Error) {
    return error.message;
  }

  return "Unknown mobile error.";
}

function clock(isoValue: string): string {
  return isoValue.slice(11, 16);
}

function formatEventLine(event: CalendarEvent): string {
  const parts = [`${clock(event.start)}-${clock(event.end)} ${event.title}`];
  if (event.location) {
    parts.push(`at ${event.location}`);
  }
  if (event.priority && event.priority !== "medium") {
    parts.push(`(${event.priority} priority)`);
  }
  return `- ${parts.join(" ")}`;
}

function formatConflictLine(conflict: CalendarConflict): string {
  return `- ${conflict.severity.toUpperCase()}: ${conflict.message}`;
}

function formatProposalLine(proposal: CalendarOperationProposal): string {
  const warningText =
    proposal.warnings.length > 0
      ? ` Warnings: ${proposal.warnings.join("; ")}.`
      : "";
  return `Proposal ${proposal.proposal_id} is ${proposal.status} for ${proposal.target_summary}.${warningText}`;
}

function formatAuditLine(record: CalendarAuditRecord): string {
  return `- ${record.result_status.toUpperCase()} ${record.operation_type} on ${record.recorded_at}: ${record.event_id ?? record.calendar_id ?? record.proposal_id}`;
}

function formatReadableDate(date: string, defaultDate: string): string {
  return date === defaultDate ? "today" : date;
}

function formatProposalWarningText(warnings: string[]): string {
  const parts: string[] = [];

  if (
    warnings.some((warning) =>
      /destructive and requires explicit confirmation/i.test(warning),
    )
  ) {
    parts.push(
      "Because this removes existing calendar data, I am holding it for confirmation.",
    );
  }
  if (warnings.some((warning) => /timing conflict warning/i.test(warning))) {
    parts.push(
      "This change may conflict with something already on your calendar.",
    );
  }

  return parts.join(" ");
}

function extractEventFromProposalState(
  proposal: CalendarOperationProposal,
): CalendarEvent | null {
  const afterState = proposal.after_state as
    | { events?: CalendarEvent[] }
    | null
    | undefined;
  return afterState?.events?.[0] ?? null;
}

function extractBeforeEventFromProposalState(
  proposal: CalendarOperationProposal,
): CalendarEvent | null {
  const beforeState = proposal.before_state as
    | { events?: CalendarEvent[] }
    | null
    | undefined;
  return beforeState?.events?.[0] ?? null;
}

function formatDraftedProposalResponse(
  action: Extract<
    AgentAction,
    { kind: "createProposal" | "createCalendar" | "deleteCalendar" }
  >,
  proposal: CalendarOperationProposal,
  defaultDate: string,
): string {
  if (
    action.kind === "createProposal" &&
    action.payload.operation_type === "create_event"
  ) {
    const event = action.payload.event as
      | {
          title?: string;
          start?: string;
          end?: string;
          location?: string;
        }
      | undefined;
    const title = event?.title ?? "Meeting";
    const start = event?.start;
    const end = event?.end;
    const date = start?.slice(0, 10) ?? defaultDate;
    const timeLabel =
      start && end ? `${clock(start)} to ${clock(end)}` : "the requested time";
    const locationLabel = event?.location ? ` via ${event.location}` : "";
    const calendarId =
      (action.payload.calendar_id as string | undefined) ??
      proposal.calendar_id ??
      "primary";

    return `All right. I've drafted "${title}" for ${formatReadableDate(date, defaultDate)} from ${timeLabel}${locationLabel} on your ${calendarId} calendar. Say "execute latest" when you want me to place it.`;
  }

  if (action.kind === "createCalendar") {
    return `All right. I've drafted a new calendar named "${action.payload.calendar.name}". Say "execute latest" when you want me to create it.`;
  }

  if (action.kind === "deleteCalendar") {
    return `All right. I've prepared the deletion of calendar "${action.payload.calendar_id}". ${formatProposalWarningText(proposal.warnings)} Say "execute latest" when you want me to apply it.`;
  }

  if (
    action.kind === "createProposal" &&
    action.payload.operation_type === "delete_event"
  ) {
    const event = extractBeforeEventFromProposalState(proposal);
    const eventName = event?.title ?? "that event";
    return `Understood. I've prepared the cancellation of "${eventName}" from your ${proposal.calendar_id ?? "primary"} calendar. ${formatProposalWarningText(proposal.warnings)} Say "execute latest" when you want me to remove it.`;
  }

  return formatProposalLine(proposal);
}

function formatExecutedProposalResponse(
  proposal: CalendarOperationProposal,
  defaultDate: string,
): string {
  if (proposal.operation_type === "create_event") {
    const event = extractEventFromProposalState(proposal);
    if (event) {
      const locationLabel = event.location ? ` via ${event.location}` : "";
      return `Done. "${event.title}" has been added to your calendar for ${formatReadableDate(event.start.slice(0, 10), defaultDate)} from ${clock(event.start)} to ${clock(event.end)}${locationLabel}.`;
    }
    return "Done. The event has been added to your calendar.";
  }

  if (proposal.operation_type === "delete_event") {
    const event = extractBeforeEventFromProposalState(proposal);
    if (event) {
      return `Done. "${event.title}" has been removed from your calendar.`;
    }
    return "Done. The event has been removed from your calendar.";
  }

  if (proposal.operation_type === "move_event") {
    const event = extractEventFromProposalState(proposal);
    if (event) {
      return `Done. "${event.title}" has been moved to ${formatReadableDate(event.start.slice(0, 10), defaultDate)} from ${clock(event.start)} to ${clock(event.end)}.`;
    }
    return "Done. The event has been moved.";
  }

  if (proposal.operation_type === "update_event") {
    const event = extractEventFromProposalState(proposal);
    if (event) {
      return `Done. "${event.title}" has been updated on your calendar.`;
    }
    return "Done. The event has been updated.";
  }

  if (proposal.operation_type === "create_calendar") {
    return "Done. The new calendar has been created.";
  }

  if (proposal.operation_type === "delete_calendar") {
    return "Done. The calendar has been deleted.";
  }

  return "Done. The calendar change has been applied.";
}

function categoryForAction(action: AgentAction): string {
  switch (action.kind) {
    case "showCalendars":
    case "inspectCalendar":
    case "showEvents":
    case "showConflicts":
    case "showSummary":
    case "showProposals":
    case "showProposal":
    case "showAudit":
    case "createCalendar":
    case "deleteCalendar":
    case "createProposal":
    case "executeProposal":
    case "rejectProposal":
      return "calendar";
    case "showBriefing":
      return "briefing";
    case "refresh":
      return "system status";
    case "help":
      return "help";
  }
}

function unavailableMessageForAction(action: AgentAction, error: unknown): string {
  if (action.kind === "help") {
    return HELP_TEXT;
  }
  return `The ${categoryForAction(action)} data is not attainable at the moment, so I cannot answer that request reliably.\n\n${formatApiError(error)}`;
}

function unavailableMessageForInterpretation(error: unknown): string {
  return `The agent command interpreter is not attainable at the moment, so I cannot safely process that instruction.\n\n${formatApiError(error)}`;
}

function isContextualReadAction(
  action: AgentAction,
): action is ContextualReadAction {
  return (
    action.kind === "showEvents" ||
    action.kind === "showConflicts" ||
    action.kind === "showSummary" ||
    action.kind === "showBriefing"
  );
}

function deriveFollowUpReadAction(
  prompt: string,
  lastAction: ContextualReadAction | null,
): ContextualReadAction | null {
  if (!lastAction) {
    return null;
  }

  const normalized = prompt
    .trim()
    .toLowerCase()
    .replace(/[?!.,]/g, " ")
    .replace(/\s+/g, " ");
  const match = normalized.match(
    /^(?:how about|what about|and|then)?\s*(yesterday|today|tomorrow)\s*$/,
  );
  if (!match) {
    return null;
  }

  const offset =
    match[1] === "yesterday" ? -1 : match[1] === "tomorrow" ? 1 : 0;
  const anchorDate =
    "date" in lastAction && lastAction.date ? lastAction.date : getLocalDate();
  const nextDate = shiftIsoDate(anchorDate, offset);

  if (lastAction.kind === "showBriefing") {
    return { kind: "showBriefing", date: nextDate };
  }

  return {
    kind: lastAction.kind,
    calendarId: lastAction.calendarId,
    date: nextDate,
  };
}

function extractSuggestedActionFromClarification(
  message: string,
): AgentAction | null {
  const schedule = message.match(
    /\b(schedule|conflicts|summary)\s+for\s+(\d{4}-\d{2}-\d{2})\s+on\s+calendar\s+(\S+)\b/i,
  );
  if (schedule) {
    const kind = schedule[1].toLowerCase();
    const date = schedule[2];
    const calendarId = schedule[3];
    if (kind === "conflicts") {
      return { kind: "showConflicts", calendarId, date };
    }
    if (kind === "summary") {
      return { kind: "showSummary", calendarId, date };
    }
    return { kind: "showEvents", calendarId, date };
  }

  const briefing = message.match(/\bbriefing\s+for\s+(\d{4}-\d{2}-\d{2})\b/i);
  if (briefing) {
    return { kind: "showBriefing", date: briefing[1] };
  }

  return null;
}

function resolveParseContext(state: JarvisState): ParseContext {
  return {
    defaultDate: state.defaultDate,
    defaultCalendarId: state.defaultCalendarId,
    latestProposalId: state.latestProposalId,
  };
}

async function resolveLatestProposal(
  state: JarvisState,
  fallbackProposalId?: string,
): Promise<string | null> {
  if (fallbackProposalId && fallbackProposalId !== "latest") {
    return fallbackProposalId;
  }
  if (state.latestProposalId) {
    return state.latestProposalId;
  }
  const response = await api.proposals();
  const latest = [...response.operations].sort(
    (left, right) => Date.parse(right.created_at) - Date.parse(left.created_at),
  )[0];
  return latest?.proposal_id ?? null;
}

async function executeAction(
  state: JarvisState,
  action: AgentAction,
): Promise<{
  answer: string;
  defaultDate?: string;
  defaultCalendarId?: string;
  latestProposalId?: string;
}> {
  switch (action.kind) {
    case "help":
      return { answer: HELP_TEXT };
    case "refresh": {
      const [healthResult, summaryResult] = await Promise.allSettled([
        api.health(),
        api.summary(state.defaultCalendarId, { date: state.defaultDate }),
      ]);
      const lines: string[] = [];
      if (healthResult.status === "fulfilled") {
        lines.push(
          `Backend is ${healthResult.value.status}. Mock mode is ${healthResult.value.use_mocks ? "enabled" : "disabled"} and the model is ${healthResult.value.model}.`,
        );
      } else {
        lines.push(
          `System status data is not attainable at the moment.\n\n${formatApiError(healthResult.reason)}`,
        );
      }
      if (summaryResult.status === "fulfilled") {
        lines.push(
          `Current calendar summary for ${state.defaultDate}: ${summaryResult.value.summary}`,
        );
      } else {
        lines.push(
          `Calendar data is not attainable at the moment, so the current summary cannot be retrieved reliably.\n\n${formatApiError(summaryResult.reason)}`,
        );
      }
      return { answer: lines.join("\n\n") };
    }
    case "showCalendars": {
      const response = await api.calendars();
      return {
        answer:
          response.calendars.length === 0
            ? "No calendars are currently available."
            : [
                "Available calendars:",
                ...response.calendars.map(
                  (calendar) =>
                    `- ${calendar.id}: ${calendar.name} (${calendar.timezone})${calendar.is_primary ? " [primary]" : ""}`,
                ),
              ].join("\n"),
      };
    }
    case "inspectCalendar": {
      const response = await api.calendarDetail(action.calendarId);
      return {
        answer: `Calendar ${response.calendar.id} is ${response.calendar.name}. Timezone: ${response.calendar.timezone}. Primary: ${response.calendar.is_primary ? "yes" : "no"}.`,
        defaultCalendarId: response.calendar.id,
      };
    }
    case "showEvents": {
      const response = await api.events(action.calendarId, { date: action.date });
      return {
        answer:
          response.events.length === 0
            ? `No events are scheduled for ${action.date} on calendar ${action.calendarId}.`
            : [
                `Schedule for ${action.date} on ${action.calendarId}:`,
                ...response.events.map(formatEventLine),
              ].join("\n"),
        defaultCalendarId: action.calendarId,
        defaultDate: action.date,
      };
    }
    case "showConflicts": {
      const response = await api.conflicts(action.calendarId, {
        date: action.date,
      });
      return {
        answer:
          response.conflicts.length === 0
            ? `No conflicts detected for ${action.date} on calendar ${action.calendarId}.`
            : [
                `Conflicts for ${action.date} on ${action.calendarId}:`,
                ...response.conflicts.map(formatConflictLine),
              ].join("\n"),
        defaultCalendarId: action.calendarId,
        defaultDate: action.date,
      };
    }
    case "showSummary": {
      const response = await api.summary(action.calendarId, { date: action.date });
      return {
        answer: [
          `Summary for ${action.date} on ${action.calendarId}: ${response.summary}`,
          ...(response.events.length > 0
            ? ["", ...response.events.slice(0, 4).map(formatEventLine)]
            : []),
        ].join("\n"),
        defaultCalendarId: action.calendarId,
        defaultDate: action.date,
      };
    }
    case "showProposals": {
      const response = await api.proposals();
      const proposals = [...response.operations].sort(
        (left, right) => Date.parse(right.created_at) - Date.parse(left.created_at),
      );
      return {
        answer:
          proposals.length === 0
            ? "There are no calendar proposals waiting in the system."
            : ["Current proposals:", ...proposals.slice(0, 6).map(formatProposalLine)].join(
                "\n",
              ),
        latestProposalId: proposals[0]?.proposal_id,
      };
    }
    case "showProposal": {
      const proposalId = await resolveLatestProposal(state, action.proposalId);
      if (!proposalId) {
        return { answer: "There is no proposal available to inspect." };
      }
      const response = await api.proposal(proposalId);
      return {
        answer: [
          `Proposal ${response.proposal_id}`,
          `Status: ${response.status}`,
          `Operation: ${response.operation_type}`,
          `Target: ${response.target_summary}`,
          `Snapshot: ${response.snapshot_hash}`,
          ...(response.warnings.length > 0
            ? [`Warnings: ${response.warnings.join("; ")}`]
            : []),
        ].join("\n"),
        latestProposalId: response.proposal_id,
      };
    }
    case "showAudit": {
      const response = await api.audit();
      return {
        answer:
          response.records.length === 0
            ? "The audit trail is currently empty."
            : [
                "Recent audit records:",
                ...response.records.slice(0, 6).map(formatAuditLine),
              ].join("\n"),
      };
    }
    case "showBriefing": {
      const response = await api.briefing(action.date);
      return {
        answer: [
          response.headline,
          response.final_summary,
          "",
          `Calendar: ${response.calendar.summary}`,
        ].join("\n"),
        defaultDate: action.date,
      };
    }
    case "createCalendar":
    case "deleteCalendar":
    case "createProposal": {
      const payload = action.payload;
      const response = await api.createProposal(payload);
      return {
        answer: formatDraftedProposalResponse(action, response, state.defaultDate),
        latestProposalId: response.proposal_id,
        defaultCalendarId:
          response.calendar_id ?? state.defaultCalendarId,
      };
    }
    case "executeProposal": {
      const proposalId = await resolveLatestProposal(state, action.proposalId);
      if (!proposalId) {
        return { answer: "There is no proposal available to execute." };
      }
      const proposal = await api.proposal(proposalId);
      await api.executeProposal(proposal.proposal_id, {
        proposal_id: proposal.proposal_id,
        snapshot_hash: proposal.snapshot_hash,
        confirmed: true,
      });
      return {
        answer: formatExecutedProposalResponse(proposal, state.defaultDate),
        latestProposalId: proposal.proposal_id,
      };
    }
    case "rejectProposal": {
      const proposalId = await resolveLatestProposal(state, action.proposalId);
      if (!proposalId) {
        return { answer: "There is no proposal available to reject." };
      }
      await api.rejectProposal(proposalId, { proposal_id: proposalId });
      return {
        answer: "Understood. I have discarded that drafted change.",
        latestProposalId: proposalId,
      };
    }
  }
}

export const useJarvisStore = create<JarvisState>((set, get) => ({
  messages: [],
  draft: "",
  phase: "idle",
  hasStarted: false,
  isBooting: false,
  backendStatus: "idle",
  defaultDate: getLocalDate(),
  defaultCalendarId: "primary",
  latestProposalId: undefined,
  lastContextualReadAction: null,
  pendingConfirmation: null,
  pendingEventDraft: null,
  setDraft: (value) => set({ draft: value }),
  startAssistant: async () => {
    if (get().hasStarted && !get().isBooting) {
      return;
    }

    const today = getLocalDate();
    set({
      hasStarted: true,
      isBooting: true,
      phase: "thinking",
      defaultDate: today,
    });

    try {
      const response = await api.startupGreeting({
        user_name: "Operator",
        location: "Seoul",
        date: today,
      });
      set({
        messages: [makeMessage("assistant", response.greeting)],
        phase: "idle",
        isBooting: false,
        backendStatus: "connected",
      });
    } catch (error) {
      set({
        messages: [
          makeMessage(
            "assistant",
            `Startup greeting unavailable. ${formatApiError(error)}`,
          ),
        ],
        phase: "idle",
        isBooting: false,
        backendStatus: "degraded",
      });
    }
  },
  submitPrompt: async (prompt) => {
    const text = prompt.trim();
    if (!text) {
      return;
    }

    set((state) => ({
      messages: [...state.messages, makeMessage("user", text)],
      draft: "",
      phase: "thinking",
    }));

    const state = get();
    const normalizedPrompt = text.toLowerCase();

    try {
      if (state.pendingConfirmation) {
        if (/^(yes|yeah|yep|please do|do it|go ahead|sure|okay|ok)\b/.test(normalizedPrompt)) {
          set({ pendingConfirmation: null });
          const result = await executeAction(get(), state.pendingConfirmation.action);
          set((current) => ({
            messages: [...current.messages, makeMessage("assistant", result.answer)],
            phase: "speaking",
            backendStatus: "connected",
            latestProposalId: result.latestProposalId ?? current.latestProposalId,
            defaultDate: result.defaultDate ?? current.defaultDate,
            defaultCalendarId:
              result.defaultCalendarId ?? current.defaultCalendarId,
            lastContextualReadAction: isContextualReadAction(
              state.pendingConfirmation!.action,
            )
              ? state.pendingConfirmation!.action
              : current.lastContextualReadAction,
          }));
          setTimeout(() => set({ phase: "idle" }), 450);
          return;
        }

        if (/^(no|nope|cancel|never mind|nevermind)\b/.test(normalizedPrompt)) {
          set((current) => ({
            pendingConfirmation: null,
            messages: [
              ...current.messages,
              makeMessage(
                "assistant",
                "Understood. I will leave that request unresolved.",
              ),
            ],
            phase: "speaking",
          }));
          setTimeout(() => set({ phase: "idle" }), 450);
          return;
        }
      }

      if (state.pendingEventDraft) {
        if (/^(cancel|stop|never mind|nevermind|nope)$/i.test(normalizedPrompt)) {
          set((current) => ({
            pendingEventDraft: null,
            messages: [
              ...current.messages,
              makeMessage("assistant", "Understood. I will not draft that event."),
            ],
            phase: "speaking",
          }));
          setTimeout(() => set({ phase: "idle" }), 450);
          return;
        }

        const updatedDraft = continuePendingEventDraft(text, state.pendingEventDraft);
        if (!isEventDraftComplete(updatedDraft)) {
          set((current) => ({
            pendingEventDraft: updatedDraft,
            messages: [
              ...current.messages,
              makeMessage("assistant", buildEventDraftPrompt(updatedDraft)),
            ],
            phase: "speaking",
          }));
          setTimeout(() => set({ phase: "idle" }), 450);
          return;
        }

        const action = buildCreateProposalFromDraft(updatedDraft);
        const result = await executeAction(get(), action);
        set((current) => ({
          pendingEventDraft: null,
          messages: [...current.messages, makeMessage("assistant", result.answer)],
          phase: "speaking",
          backendStatus: "connected",
          latestProposalId: result.latestProposalId ?? current.latestProposalId,
          defaultDate: result.defaultDate ?? current.defaultDate,
          defaultCalendarId:
            result.defaultCalendarId ?? current.defaultCalendarId,
        }));
        setTimeout(() => set({ phase: "idle" }), 450);
        return;
      }

      const followUp = deriveFollowUpReadAction(text, state.lastContextualReadAction);
      if (followUp) {
        const result = await executeAction(get(), followUp);
        set((current) => ({
          messages: [...current.messages, makeMessage("assistant", result.answer)],
          phase: "speaking",
          backendStatus: "connected",
          defaultDate: result.defaultDate ?? current.defaultDate,
          defaultCalendarId:
            result.defaultCalendarId ?? current.defaultCalendarId,
          lastContextualReadAction: followUp,
        }));
        setTimeout(() => set({ phase: "idle" }), 450);
        return;
      }

      const direct = parseCommand(text, resolveParseContext(get()));
      if (direct) {
        const result = await executeAction(get(), direct);
        set((current) => ({
          messages: [...current.messages, makeMessage("assistant", result.answer)],
          phase: "speaking",
          backendStatus: "connected",
          latestProposalId: result.latestProposalId ?? current.latestProposalId,
          defaultDate: result.defaultDate ?? current.defaultDate,
          defaultCalendarId:
            result.defaultCalendarId ?? current.defaultCalendarId,
          lastContextualReadAction: isContextualReadAction(direct)
            ? direct
            : current.lastContextualReadAction,
          pendingConfirmation: null,
        }));
        setTimeout(() => set({ phase: "idle" }), 450);
        return;
      }

      const eventDraft = inferPendingEventDraft(text, resolveParseContext(get()));
      if (eventDraft) {
        set((current) => ({
          pendingEventDraft: eventDraft,
          messages: [
            ...current.messages,
            makeMessage("assistant", buildEventDraftPrompt(eventDraft)),
          ],
          phase: "speaking",
          backendStatus: "connected",
        }));
        setTimeout(() => set({ phase: "idle" }), 450);
        return;
      }

      let interpretation;
      try {
        interpretation = await api.interpretCommand({
          input: text,
          date: get().defaultDate,
          calendar_id: get().defaultCalendarId,
          latest_proposal_id: get().latestProposalId,
        });
      } catch (error) {
        throw new Error(unavailableMessageForInterpretation(error));
      }

      if (
        interpretation.status === "clarify" ||
        !interpretation.command
      ) {
        const suggestedAction =
          extractSuggestedActionFromClarification(interpretation.explanation) ??
          undefined;
        set((current) => ({
          pendingConfirmation: suggestedAction ? { action: suggestedAction } : null,
          messages: [
            ...current.messages,
            makeMessage("assistant", interpretation.explanation),
          ],
          phase: "speaking",
          backendStatus: "connected",
        }));
        setTimeout(() => set({ phase: "idle" }), 450);
        return;
      }

      const normalizedAction = parseCommand(
        interpretation.command,
        resolveParseContext(get()),
      );

      if (!normalizedAction) {
        set((current) => ({
          messages: [
            ...current.messages,
            makeMessage(
              "assistant",
              "The backend normalized the instruction, but the mobile client could not execute the resulting command safely.",
            ),
          ],
          phase: "speaking",
          backendStatus: "degraded",
        }));
        setTimeout(() => set({ phase: "idle" }), 450);
        return;
      }

      const result = await executeAction(get(), normalizedAction);
      set((current) => ({
        messages: [...current.messages, makeMessage("assistant", result.answer)],
        phase: "speaking",
        backendStatus: "connected",
        latestProposalId: result.latestProposalId ?? current.latestProposalId,
        defaultDate: result.defaultDate ?? current.defaultDate,
        defaultCalendarId:
          result.defaultCalendarId ?? current.defaultCalendarId,
        lastContextualReadAction: isContextualReadAction(normalizedAction)
          ? normalizedAction
          : current.lastContextualReadAction,
        pendingConfirmation: null,
      }));
      setTimeout(() => set({ phase: "idle" }), 450);
    } catch (error) {
      set((current) => ({
        messages: [
          ...current.messages,
          makeMessage("assistant", formatApiError(error)),
        ],
        phase: "speaking",
        backendStatus: "degraded",
      }));
      setTimeout(() => set({ phase: "idle" }), 450);
    }
  },
}));
