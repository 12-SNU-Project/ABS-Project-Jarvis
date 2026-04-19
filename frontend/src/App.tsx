import { ChevronLeft, ChevronRight, Mic } from "lucide-react";
import {
  startTransition,
  useEffect,
  useMemo,
  useRef,
  useState,
  type Dispatch,
  type SetStateAction,
} from "react";

import { AssistantSphere } from "./components/AssistantSphere";
import {
  HELP_TEXT,
  buildCreateProposalFromDraft,
  buildEventDraftPrompt,
  continuePendingEventDraft,
  inferPendingEventDraft,
  isEventDraftComplete,
  parseCommand,
  type AgentAction,
  type PendingEventDraft,
} from "./lib/agent";
import { ApiError, createApi } from "./lib/api";
import { API_BASE_URL } from "./lib/config";
import { startupGreetingApi } from "./lib/startupGreetingApi";
import { synthesizeVoice, transcribeVoice } from "./lib/voiceApi";
import type {
  CalendarAuditRecord,
  CalendarConflict,
  CalendarEvent,
  CalendarOperationProposal,
} from "./lib/types";

type AssistantPhase = "idle" | "thinking" | "speaking" | "listening";
type ListeningMode = "wake" | "command" | null;

type ChatMessage = {
  id: string;
  role: "assistant" | "user";
  text: string;
};

type ContextualReadAction = Extract<
  AgentAction,
  { kind: "showEvents" | "showConflicts" | "showSummary" | "showBriefing" }
>;

type PendingConfirmation = {
  action: AgentAction;
};

type SpeechRecognitionCtor = new () => {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  onresult: ((event: SpeechRecognitionEventLike) => void) | null;
  onerror: ((event: unknown) => void) | null;
  onend: (() => void) | null;
  start: () => void;
  stop: () => void;
};

type SpeechRecognitionResultLike = {
  isFinal: boolean;
  0: {
    transcript: string;
  };
};

type SpeechRecognitionEventLike = {
  resultIndex: number;
  results: ArrayLike<SpeechRecognitionResultLike>;
};

declare global {
  interface Window {
    SpeechRecognition?: SpeechRecognitionCtor;
    webkitSpeechRecognition?: SpeechRecognitionCtor;
  }
}

function getSpeechRecognitionCtor(): SpeechRecognitionCtor | null {
  if (typeof window === "undefined") {
    return null;
  }

  return window.SpeechRecognition ?? window.webkitSpeechRecognition ?? null;
}

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

function clock(isoValue: string): string {
  return isoValue.slice(11, 16);
}

function formatEventLine(event: CalendarEvent): string {
  const segments = [`${clock(event.start)}-${clock(event.end)} ${event.title}`];

  if (event.location) {
    segments.push(`at ${event.location}`);
  }

  if (event.priority && event.priority !== "medium") {
    segments.push(`(${event.priority} priority)`);
  }

  return `- ${segments.join(" ")}`;
}

function formatConflictLine(conflict: CalendarConflict): string {
  return `- ${conflict.severity.toUpperCase()}: ${conflict.message}`;
}

function formatProposalLine(proposal: CalendarOperationProposal): string {
  const warnings =
    proposal.warnings.length > 0
      ? ` Warnings: ${proposal.warnings.join("; ")}.`
      : "";

  return `Proposal ${proposal.proposal_id} is ${proposal.status} for ${proposal.target_summary}.${warnings}`;
}

function formatAuditLine(record: CalendarAuditRecord): string {
  return `- ${record.result_status.toUpperCase()} ${record.operation_type} on ${record.recorded_at}: ${record.event_id ?? record.calendar_id ?? record.proposal_id}`;
}

function formatReadableDate(date: string, defaultDate: string): string {
  if (date === defaultDate) {
    return "today";
  }
  return date;
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
    const calendarId =
      (action.payload.calendar_id as string | undefined) ??
      proposal.calendar_id ??
      "primary";
    const title = event?.title ?? "Meeting";
    const start = event?.start;
    const end = event?.end;
    const date = start?.slice(0, 10) ?? defaultDate;
    const dateLabel = formatReadableDate(date, defaultDate);
    const timeLabel =
      start && end ? `${clock(start)} to ${clock(end)}` : "the requested time";
    const locationLabel = event?.location ? ` via ${event.location}` : "";
    const warningLine =
      proposal.warnings.length > 0
        ? `\nWarnings: ${proposal.warnings.join("; ")}`
        : "";

    return `All right. I've drafted "${title}" for ${dateLabel} from ${timeLabel}${locationLabel} on your ${calendarId} calendar. Say "execute latest" when you want me to place it.${warningLine}`;
  }

  if (action.kind === "createCalendar") {
    const name = action.payload.calendar.name;
    return `All right. I've drafted a new calendar named "${name}". Say "execute latest" when you want me to create it.`;
  }

  if (action.kind === "deleteCalendar") {
    const warningText = formatProposalWarningText(proposal.warnings);
    return `All right. I've prepared the deletion of calendar "${action.payload.calendar_id}". ${warningText} Say "execute latest" when you want me to apply it.`;
  }

  if (
    action.kind === "createProposal" &&
    action.payload.operation_type === "delete_event"
  ) {
    const beforeState = proposal.before_state as
      | { events?: CalendarEvent[] }
      | null
      | undefined;
    const event = beforeState?.events?.[0];
    const eventName = event?.title ?? "that event";
    const warningText = formatProposalWarningText(proposal.warnings);
    return `Understood. I've prepared the cancellation of "${eventName}" from your ${proposal.calendar_id ?? "primary"} calendar. ${warningText} Say "execute latest" when you want me to remove it.`;
  }

  return formatProposalLine(proposal);
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

function formatExecutedProposalResponse(
  proposal: CalendarOperationProposal,
  defaultDate: string,
): string {
  if (proposal.operation_type === "create_event") {
    const event = extractEventFromProposalState(proposal);
    if (event) {
      const dateLabel = formatReadableDate(event.start.slice(0, 10), defaultDate);
      const locationLabel = event.location ? ` via ${event.location}` : "";
      return `Done. "${event.title}" has been added to your calendar for ${dateLabel} from ${clock(event.start)} to ${clock(event.end)}${locationLabel}.`;
    }
    return "Done. The event has been added to your calendar.";
  }

  if (proposal.operation_type === "create_calendar") {
    return "Done. The new calendar has been created.";
  }

  if (proposal.operation_type === "delete_calendar") {
    return "Done. The calendar has been deleted.";
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
      const dateLabel = formatReadableDate(event.start.slice(0, 10), defaultDate);
      return `Done. "${event.title}" has been moved to ${dateLabel} from ${clock(event.start)} to ${clock(event.end)}.`;
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

  return "Done. The calendar change has been applied.";
}

function formatApiError(error: unknown): string {
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

  if (error instanceof ApiError) {
    const detail = error.body?.error.details?.[0];
    const detailText = detail
      ? ` (${detail.field ?? "request"}: ${detail.message})`
      : "";

    return `Backend request failed with ${error.status}: ${error.message}${detailText}`;
  }

  if (error instanceof Error) {
    return error.message;
  }

  return "Unknown frontend error.";
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

function extensionForMimeType(mimeType: string): string {
  if (mimeType.includes("mp4")) {
    return "mp4";
  }
  if (mimeType.includes("ogg") || mimeType.includes("opus")) {
    return "ogg";
  }
  if (mimeType.includes("wav")) {
    return "wav";
  }
  return "webm";
}

function decodeBase64Audio(value: string): Uint8Array {
  const binary = window.atob(value);
  const bytes = new Uint8Array(binary.length);

  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }

  return bytes;
}

function unavailableMessageForAction(
  action: AgentAction,
  error: unknown,
): string {
  if (action.kind === "help") {
    return HELP_TEXT;
  }

  const category = categoryForAction(action);
  return `The ${category} data is not attainable at the moment, so I cannot answer that request reliably.\n\n${formatApiError(error)}`;
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

function useAssistantOutput(
  setMessages: Dispatch<SetStateAction<ChatMessage[]>>,
  setPhase: Dispatch<SetStateAction<AssistantPhase>>,
) {
  const timersRef = useRef<number[]>([]);
  const intervalRef = useRef<number | null>(null);

  const clearTimers = () => {
    timersRef.current.forEach((timer) => window.clearTimeout(timer));
    timersRef.current = [];

    if (intervalRef.current !== null) {
      window.clearInterval(intervalRef.current);
      intervalRef.current = null;
    }
  };

  useEffect(() => clearTimers, []);

  const run = (text: string) => {
    clearTimers();

    const assistantMessageId = crypto.randomUUID();
    const finalText = text.trim() || "Understood.";

    startTransition(() => {
      setPhase("speaking");
      setMessages((current) => [
        ...current,
        { id: assistantMessageId, role: "assistant", text: "" },
      ]);
    });

    let cursor = 0;
    intervalRef.current = window.setInterval(() => {
      cursor += Math.max(2, Math.ceil(Math.random() * 5));
      const nextText = finalText.slice(0, cursor);

      startTransition(() => {
        setMessages((current) => {
          if (current.length === 0) {
            return current;
          }

          const lastIndex = current.length - 1;
          const lastMessage = current[lastIndex];
          if (lastMessage.id !== assistantMessageId) {
            return current;
          }

          const nextMessages = current.slice();
          nextMessages[lastIndex] = { ...lastMessage, text: nextText };
          return nextMessages;
        });
      });

      if (cursor >= finalText.length) {
        if (intervalRef.current !== null) {
          window.clearInterval(intervalRef.current);
          intervalRef.current = null;
        }
        startTransition(() => {
          setPhase("idle");
        });
      }
    }, 28);
  };

  return {
    clearTimers,
    run,
  };
}

export default function App() {
  const api = useMemo(() => createApi(API_BASE_URL), []);

  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [draft, setDraft] = useState("");
  const [phase, setPhase] = useState<AssistantPhase>("idle");
  const [listeningMode, setListeningMode] = useState<ListeningMode>(null);
  const [isChatCollapsed, setIsChatCollapsed] = useState(false);
  const [hasStarted, setHasStarted] = useState(false);
  const [isBooting, setIsBooting] = useState(false);
  const [isAudioSpeaking, setIsAudioSpeaking] = useState(false);
  const [defaultDate, setDefaultDate] = useState(getLocalDate);
  const [defaultCalendarId, setDefaultCalendarId] = useState("primary");
  const [latestProposalId, setLatestProposalId] = useState<string | undefined>();
  const [lastContextualReadAction, setLastContextualReadAction] =
    useState<ContextualReadAction | null>(null);
  const [pendingConfirmation, setPendingConfirmation] =
    useState<PendingConfirmation | null>(null);
  const [pendingEventDraft, setPendingEventDraft] =
    useState<PendingEventDraft | null>(null);

  const logRef = useRef<HTMLDivElement | null>(null);
  const inputRef = useRef<HTMLInputElement | null>(null);
  const recognitionRef = useRef<InstanceType<SpeechRecognitionCtor> | null>(null);
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const mediaStreamRef = useRef<MediaStream | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);
  const playbackAudioRef = useRef<HTMLAudioElement | null>(null);
  const playbackUrlRef = useRef<string | null>(null);
  const wakeShouldRestartRef = useRef(false);
  const shouldStickToBottomRef = useRef(true);
  const hasStartedRef = useRef(hasStarted);
  const isChatCollapsedRef = useRef(isChatCollapsed);
  const queuedPromptRef = useRef<string | null>(null);

  const speechSupported = Boolean(getSpeechRecognitionCtor());
  const recordingSupported =
    typeof window !== "undefined" &&
    typeof MediaRecorder !== "undefined" &&
    Boolean(navigator.mediaDevices?.getUserMedia);
  const assistantOutput = useAssistantOutput(setMessages, setPhase);

  useEffect(() => {
    hasStartedRef.current = hasStarted;
  }, [hasStarted]);

  useEffect(() => {
    isChatCollapsedRef.current = isChatCollapsed;
  }, [isChatCollapsed]);

  useEffect(() => {
    if (!logRef.current) {
      return;
    }

    if (shouldStickToBottomRef.current) {
      logRef.current.scrollTop = logRef.current.scrollHeight;
    }
  }, [messages, isBooting]);

  useEffect(() => {
    if (!hasStarted || isBooting || isChatCollapsed || listeningMode === "command") {
      return;
    }

    inputRef.current?.focus();
  }, [hasStarted, isBooting, isChatCollapsed, listeningMode]);

  const stopRecognition = () => {
    wakeShouldRestartRef.current = false;

    const recognition = recognitionRef.current;
    if (!recognition) {
      return;
    }

    recognition.onend = null;
    recognition.onerror = null;
    recognition.onresult = null;

    try {
      recognition.stop();
    } catch {
      // Browser speech APIs can throw if stop() is called redundantly.
    }

    recognitionRef.current = null;
  };

  const cleanupRecording = () => {
    const recorder = mediaRecorderRef.current;
    if (recorder) {
      recorder.ondataavailable = null;
      recorder.onerror = null;
      recorder.onstop = null;

      if (recorder.state !== "inactive") {
        try {
          recorder.stop();
        } catch {
          // noop
        }
      }
    }

    mediaRecorderRef.current = null;
    audioChunksRef.current = [];

    const stream = mediaStreamRef.current;
    if (stream) {
      stream.getTracks().forEach((track) => track.stop());
    }
    mediaStreamRef.current = null;
  };

  const stopPlayback = () => {
    setIsAudioSpeaking(false);
    const audio = playbackAudioRef.current;
    if (audio) {
      audio.pause();
      audio.src = "";
      playbackAudioRef.current = null;
    }

    const playbackUrl = playbackUrlRef.current;
    if (playbackUrl) {
      URL.revokeObjectURL(playbackUrl);
      playbackUrlRef.current = null;
    }
  };

  const scrollToBottom = () => {
    const log = logRef.current;
    if (!log) {
      return;
    }

    shouldStickToBottomRef.current = true;
    log.scrollTop = log.scrollHeight;
  };

  const speakAssistant = async (text: string) => {
    const trimmed = text.trim();
    if (!trimmed) {
      return;
    }

    try {
      stopPlayback();
      const response = await synthesizeVoice({
        text: trimmed,
        instructions:
          "Speak in a poised, concise assistant tone with calm confidence.",
      });

      const bytes = decodeBase64Audio(response.audio_base64);
      const audioBuffer = new ArrayBuffer(bytes.byteLength);
      new Uint8Array(audioBuffer).set(bytes);
      const blob = new Blob([audioBuffer], { type: response.mime_type });
      const url = URL.createObjectURL(blob);
      const audio = new Audio(url);

      playbackAudioRef.current = audio;
      playbackUrlRef.current = url;
      audio.onplay = () => {
        setIsAudioSpeaking(true);
      };
      audio.onpause = () => {
        if (!audio.ended) {
          setIsAudioSpeaking(false);
        }
      };

      audio.onended = () => {
        setIsAudioSpeaking(false);
        if (playbackAudioRef.current === audio) {
          playbackAudioRef.current = null;
        }
        if (playbackUrlRef.current === url) {
          URL.revokeObjectURL(url);
          playbackUrlRef.current = null;
        }
      };

      await audio.play();
    } catch {
      setIsAudioSpeaking(false);
      stopPlayback();
    }
  };

  const deliverAssistantText = (text: string) => {
    assistantOutput.run(text);
    void speakAssistant(text);
  };

  const resolveLatestProposal = async (
    fallbackProposalId?: string,
  ): Promise<string | null> => {
    if (fallbackProposalId && fallbackProposalId !== "latest") {
      return fallbackProposalId;
    }

    if (latestProposalId) {
      return latestProposalId;
    }

    const response = await api.proposals();
    const latest = [...response.data.operations].sort(
      (left, right) =>
        Date.parse(right.created_at) - Date.parse(left.created_at),
    )[0];

    if (!latest) {
      return null;
    }

    setLatestProposalId(latest.proposal_id);
    return latest.proposal_id;
  };

  const executeAction = async (action: AgentAction): Promise<string> => {
    switch (action.kind) {
      case "help":
        return HELP_TEXT;
      case "refresh": {
        const [healthResult, summaryResult] = await Promise.allSettled([
          api.health(),
          api.summary(defaultCalendarId, { date: defaultDate }),
        ]);

        const lines: string[] = [];

        if (healthResult.status === "fulfilled") {
          lines.push(
            `Backend is ${healthResult.value.data.status}. Mock mode is ${healthResult.value.data.use_mocks ? "enabled" : "disabled"} and the model is ${healthResult.value.data.model}.`,
          );
        } else {
          lines.push(
            `System status data is not attainable at the moment.\n\n${formatApiError(healthResult.reason)}`,
          );
        }

        if (summaryResult.status === "fulfilled") {
          lines.push(
            `Current calendar summary for ${defaultDate}: ${summaryResult.value.data.summary}`,
          );
        } else {
          lines.push(
            `Calendar data is not attainable at the moment, so the current summary cannot be retrieved reliably.\n\n${formatApiError(summaryResult.reason)}`,
          );
        }

        return lines.join("\n\n");
      }
      case "showCalendars": {
        const response = await api.calendars();
        if (response.data.calendars.length === 0) {
          return "No calendars are currently available.";
        }

        return [
          "Available calendars:",
          ...response.data.calendars.map(
            (calendar) =>
              `- ${calendar.id}: ${calendar.name} (${calendar.timezone})${calendar.is_primary ? " [primary]" : ""}`,
          ),
        ].join("\n");
      }
      case "inspectCalendar": {
        const response = await api.calendarDetail(action.calendarId);
        setDefaultCalendarId(response.data.calendar.id);

        return `Calendar ${response.data.calendar.id} is ${response.data.calendar.name}. Timezone: ${response.data.calendar.timezone}. Primary: ${response.data.calendar.is_primary ? "yes" : "no"}.`;
      }
      case "showEvents": {
        const response = await api.events(action.calendarId, { date: action.date });
        setDefaultCalendarId(action.calendarId);
        setDefaultDate(action.date);

        if (response.data.events.length === 0) {
          return `No events are scheduled for ${action.date} on calendar ${action.calendarId}.`;
        }

        return [
          `Schedule for ${action.date} on ${action.calendarId}:`,
          ...response.data.events.map(formatEventLine),
        ].join("\n");
      }
      case "showConflicts": {
        const response = await api.conflicts(action.calendarId, { date: action.date });
        setDefaultCalendarId(action.calendarId);
        setDefaultDate(action.date);

        if (response.data.conflicts.length === 0) {
          return `No conflicts detected for ${action.date} on calendar ${action.calendarId}.`;
        }

        return [
          `Conflicts for ${action.date} on ${action.calendarId}:`,
          ...response.data.conflicts.map(formatConflictLine),
        ].join("\n");
      }
      case "showSummary": {
        const response = await api.summary(action.calendarId, { date: action.date });
        setDefaultCalendarId(action.calendarId);
        setDefaultDate(action.date);

        const eventPreview = response.data.events.slice(0, 4).map(formatEventLine);
        return [
          `Summary for ${action.date} on ${action.calendarId}: ${response.data.summary}`,
          ...(eventPreview.length > 0 ? ["", ...eventPreview] : []),
        ].join("\n");
      }
      case "showProposals": {
        const response = await api.proposals();
        const proposals = [...response.data.operations].sort(
          (left, right) =>
            Date.parse(right.created_at) - Date.parse(left.created_at),
        );

        if (proposals.length === 0) {
          return "There are no calendar proposals waiting in the system.";
        }

        setLatestProposalId(proposals[0].proposal_id);

        return [
          "Current proposals:",
          ...proposals.slice(0, 6).map(formatProposalLine),
        ].join("\n");
      }
      case "showProposal": {
        const proposalId = await resolveLatestProposal(action.proposalId);
        if (!proposalId) {
          return "There is no proposal available to inspect.";
        }

        const response = await api.proposal(proposalId);
        setLatestProposalId(response.data.proposal_id);

        return [
          `Proposal ${response.data.proposal_id}`,
          `Status: ${response.data.status}`,
          `Operation: ${response.data.operation_type}`,
          `Target: ${response.data.target_summary}`,
          `Snapshot: ${response.data.snapshot_hash}`,
          ...(response.data.warnings.length > 0
            ? [`Warnings: ${response.data.warnings.join("; ")}`]
            : []),
        ].join("\n");
      }
      case "showAudit": {
        const response = await api.audit();
        if (response.data.records.length === 0) {
          return "The audit trail is currently empty.";
        }

        return [
          "Recent audit records:",
          ...response.data.records.slice(0, 6).map(formatAuditLine),
        ].join("\n");
      }
      case "showBriefing": {
        const response = await api.briefing(action.date);
        setDefaultDate(action.date);

        return [
          response.data.headline,
          response.data.final_summary,
          "",
          `Calendar: ${response.data.calendar.summary}`,
        ].join("\n");
      }
      case "createCalendar":
      case "deleteCalendar":
      case "createProposal": {
        const payload =
          action.kind === "createProposal" ? action.payload : action.payload;
        const response = await api.createProposal(payload);
        setLatestProposalId(response.data.proposal_id);

        if (response.data.calendar_id) {
          setDefaultCalendarId(response.data.calendar_id);
        }

        return formatDraftedProposalResponse(action, response.data, defaultDate);
      }
      case "executeProposal": {
        const proposalId = await resolveLatestProposal(action.proposalId);
        if (!proposalId) {
          return "There is no proposal available to execute.";
        }

        const proposalResponse = await api.proposal(proposalId);
        const proposal = proposalResponse.data;
        setLatestProposalId(proposal.proposal_id);

        const result = await api.executeProposal(proposal.proposal_id, {
          proposal_id: proposal.proposal_id,
          snapshot_hash: proposal.snapshot_hash,
          confirmed: true,
        });

        void result;
        return formatExecutedProposalResponse(proposal, defaultDate);
      }
      case "rejectProposal": {
        const proposalId = await resolveLatestProposal(action.proposalId);
        if (!proposalId) {
          return "There is no proposal available to reject.";
        }

        const result = await api.rejectProposal(proposalId, {
          proposal_id: proposalId,
        });

        setLatestProposalId(proposalId);
        void result;
        return "Understood. I have discarded that drafted change.";
      }
    }
  };

  const resolveAction = async (
    prompt: string,
  ): Promise<
    | { kind: "respond"; message: string }
    | { kind: "clarify"; message: string; suggestedAction?: AgentAction }
    | { kind: "draft_event"; draft: PendingEventDraft; message: string }
    | { kind: "execute"; action: AgentAction; normalizedCommand?: string }
  > => {
    const normalizedPrompt = prompt.trim().toLowerCase();
    if (pendingConfirmation) {
      if (/^(yes|yeah|yep|please do|do it|go ahead|sure|okay|ok)\b/.test(normalizedPrompt)) {
        setPendingConfirmation(null);
        return { kind: "execute", action: pendingConfirmation.action };
      }

      if (/^(no|nope|cancel|never mind|nevermind)\b/.test(normalizedPrompt)) {
        setPendingConfirmation(null);
        return {
          kind: "respond",
          message: "Understood. I will leave that request unresolved.",
        };
      }
    }

    if (pendingEventDraft) {
      if (/^(cancel|stop|never mind|nevermind|nope)$/i.test(normalizedPrompt)) {
        setPendingEventDraft(null);
        return {
          kind: "respond",
          message: "Understood. I will not draft that event.",
        };
      }

      const updatedDraft = continuePendingEventDraft(prompt, pendingEventDraft);
      if (isEventDraftComplete(updatedDraft)) {
        setPendingEventDraft(null);
        return {
          kind: "execute",
          action: buildCreateProposalFromDraft(updatedDraft),
        };
      }

      return {
        kind: "draft_event",
        draft: updatedDraft,
        message: buildEventDraftPrompt(updatedDraft),
      };
    }

    const contextualFollowUp = deriveFollowUpReadAction(
      prompt,
      lastContextualReadAction,
    );
    if (contextualFollowUp) {
      setPendingConfirmation(null);
      return { kind: "execute", action: contextualFollowUp };
    }

    const direct = parseCommand(prompt, {
      defaultDate,
      defaultCalendarId,
      latestProposalId,
    });

    if (direct) {
      setPendingConfirmation(null);
      return { kind: "execute", action: direct };
    }

    const eventDraft = inferPendingEventDraft(prompt, {
      defaultDate,
      defaultCalendarId,
      latestProposalId,
    });
    if (eventDraft) {
      return {
        kind: "draft_event",
        draft: eventDraft,
        message: buildEventDraftPrompt(eventDraft),
      };
    }

    let interpretation;
    try {
      interpretation = await api.interpretCommand({
        input: prompt,
        date: defaultDate,
        calendar_id: defaultCalendarId,
        latest_proposal_id: latestProposalId,
      });
    } catch (error) {
      throw new Error(unavailableMessageForInterpretation(error));
    }

    if (
      interpretation.data.status === "clarify" ||
      !interpretation.data.command
    ) {
      return {
        kind: "clarify",
        message: interpretation.data.explanation,
        suggestedAction: extractSuggestedActionFromClarification(
          interpretation.data.explanation,
        ) ?? undefined,
      };
    }

    const normalizedAction = parseCommand(interpretation.data.command, {
      defaultDate,
      defaultCalendarId,
      latestProposalId,
    });

    if (!normalizedAction) {
      return {
        kind: "clarify",
        message:
          "The backend normalized the instruction, but the frontend could not execute the resulting command safely.",
      };
    }

    setPendingConfirmation(null);
    return {
      kind: "execute",
      action: normalizedAction,
      normalizedCommand: interpretation.data.command,
    };
  };

  const submitPrompt = async (prompt: string) => {
    const text = prompt.trim();
    if (!text) {
      return;
    }

    scrollToBottom();
    setListeningMode(null);
    setMessages((current) => [
      ...current,
      { id: crypto.randomUUID(), role: "user", text },
    ]);
    setDraft("");
    setPhase("thinking");

    try {
      const resolution = await resolveAction(text);

      if (resolution.kind === "respond") {
        deliverAssistantText(resolution.message);
        return;
      }

      if (resolution.kind === "draft_event") {
        setPendingEventDraft(resolution.draft);
        deliverAssistantText(resolution.message);
        return;
      }

      if (resolution.kind === "clarify") {
        setPendingEventDraft(null);
        setPendingConfirmation(
          resolution.suggestedAction
            ? {
                action: resolution.suggestedAction,
              }
            : null,
        );
        deliverAssistantText(resolution.message);
        return;
      }

      setPendingEventDraft(null);
      let answer: string;
      try {
        answer = await executeAction(resolution.action);
      } catch (error) {
        deliverAssistantText(
          unavailableMessageForAction(resolution.action, error),
        );
        return;
      }

      if (isContextualReadAction(resolution.action)) {
        setLastContextualReadAction(resolution.action);
      }

      deliverAssistantText(answer);
    } catch (error) {
      if (error instanceof Error) {
        deliverAssistantText(error.message);
        return;
      }

      deliverAssistantText(formatApiError(error));
    }
  };

  const startAssistant = async (queuedPrompt?: string) => {
    if (queuedPrompt) {
      queuedPromptRef.current = queuedPrompt;
    }

    if (hasStartedRef.current && !isBooting) {
      if (queuedPromptRef.current) {
        const prompt = queuedPromptRef.current;
        queuedPromptRef.current = null;
        void submitPrompt(prompt);
      }
      return;
    }

    const today = getLocalDate();
    scrollToBottom();
    setHasStarted(true);
    setIsBooting(true);
    setPhase("thinking");
    setDefaultDate(today);

    try {
      const response = await startupGreetingApi.getGreeting({
        user_name: "Operator",
        location: "Seoul",
        date: today,
      });

      setMessages([
        {
          id: crypto.randomUUID(),
          role: "assistant",
          text: response.greeting,
        },
      ]);
      void speakAssistant(response.greeting);
      setPhase("idle");
    } catch (error) {
      const fallback = `Startup greeting unavailable. ${formatApiError(error)}`;
      setMessages([
        {
          id: crypto.randomUUID(),
          role: "assistant",
          text: fallback,
        },
      ]);
      void speakAssistant(fallback);
      setPhase("idle");
    } finally {
      setIsBooting(false);

      if (queuedPromptRef.current) {
        const prompt = queuedPromptRef.current;
        queuedPromptRef.current = null;
        void submitPrompt(prompt);
      }
    }
  };

  const addSpeechMessage = (text: string) => {
    deliverAssistantText(text);
  };

  const startCommandListening = async () => {
    if (!recordingSupported) {
      addSpeechMessage(
        "The voice input is not attainable at the moment. Browser audio capture support could not be detected.",
      );
      return;
    }

    stopRecognition();
    stopPlayback();
    cleanupRecording();
    setListeningMode("command");
    setPhase("listening");
    setDraft("");

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;

      const mimeType =
        [
          "audio/webm;codecs=opus",
          "audio/webm",
          "audio/mp4",
          "audio/ogg;codecs=opus",
        ].find(
          (candidate) =>
            typeof MediaRecorder.isTypeSupported !== "function" ||
            MediaRecorder.isTypeSupported(candidate),
        ) ?? "";

      const recorder = mimeType
        ? new MediaRecorder(stream, { mimeType })
        : new MediaRecorder(stream);

      audioChunksRef.current = [];
      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };
      recorder.onerror = () => {
        cleanupRecording();
        setListeningMode(null);
        setDraft("");
        setPhase("idle");
        addSpeechMessage(
          "The voice input is not attainable at the moment. Audio capture failed before transcription could begin.",
        );
      };
      recorder.onstop = async () => {
        const recordedMimeType = recorder.mimeType || "audio/webm";
        const audioBlob = new Blob(audioChunksRef.current, {
          type: recordedMimeType,
        });

        cleanupRecording();
        setListeningMode(null);
        setDraft("");

        if (audioBlob.size === 0) {
          setPhase("idle");
          addSpeechMessage(
            "The voice input is not attainable at the moment. No audio was captured for transcription.",
          );
          return;
        }

        try {
          const extension = extensionForMimeType(recordedMimeType || audioBlob.type);
          const transcription = await transcribeVoice(
            audioBlob,
            `recording.${extension}`,
          );
          const transcript = transcription.transcript.trim();

          if (!transcript) {
            setPhase("idle");
            addSpeechMessage(
              "The voice input is not attainable at the moment. The transcription completed, but it returned no usable text.",
            );
            return;
          }

          setDraft(transcript);
          void submitPrompt(transcript);
        } catch (error) {
          setPhase("idle");
          addSpeechMessage(
            `The voice input is not attainable at the moment.\n\n${formatApiError(error)}`,
          );
        }
      };

      mediaRecorderRef.current = recorder;
      recorder.start();
    } catch (error) {
      cleanupRecording();
      setListeningMode(null);
      setDraft("");
      setPhase("idle");
      addSpeechMessage(
        `The voice input is not attainable at the moment.\n\n${formatApiError(error)}`,
      );
    }
  };

  const startWakeListening = () => {
    const Recognition = getSpeechRecognitionCtor();
    if (!Recognition) {
      return;
    }

    stopRecognition();
    wakeShouldRestartRef.current = true;
    setListeningMode("wake");

    const recognition = new Recognition();
    recognition.continuous = true;
    recognition.interimResults = true;
    recognition.lang = "en-US";

    recognition.onresult = (event: SpeechRecognitionEventLike) => {
      let transcript = "";

      for (
        let index = event.resultIndex;
        index < event.results.length;
        index += 1
      ) {
        transcript += event.results[index][0].transcript;
      }

      const match = transcript.match(/hey jarvis[\s,.:;-]*(.*)$/i);
      if (!match) {
        return;
      }

      const trailingPrompt = match[1]?.trim() ?? "";
      wakeShouldRestartRef.current = false;
      recognition.onend = null;
      recognition.onerror = null;
      recognition.onresult = null;

      try {
        recognition.stop();
      } catch {
        // noop
      }

      recognitionRef.current = null;
      setListeningMode(null);
      setIsChatCollapsed(false);

      if (!hasStartedRef.current) {
        void startAssistant(trailingPrompt || undefined);
        return;
      }

      if (trailingPrompt) {
        void submitPrompt(trailingPrompt);
      } else {
        startCommandListening();
      }
    };

    recognition.onerror = () => {
      recognitionRef.current = null;
      if (wakeShouldRestartRef.current && isChatCollapsedRef.current) {
        window.setTimeout(startWakeListening, 700);
      } else {
        setListeningMode(null);
      }
    };

    recognition.onend = () => {
      recognitionRef.current = null;
      if (wakeShouldRestartRef.current && isChatCollapsedRef.current) {
        window.setTimeout(startWakeListening, 250);
      } else {
        setListeningMode(null);
      }
    };

    recognitionRef.current = recognition;
    recognition.start();
  };

  useEffect(() => {
    if (!speechSupported) {
      return;
    }

    if (isChatCollapsed && listeningMode !== "command") {
      startWakeListening();
      return;
    }

    if (!isChatCollapsed && listeningMode === "wake") {
      stopRecognition();
      setListeningMode(null);
    }
  }, [isChatCollapsed, speechSupported]);

  useEffect(
    () => () => {
      stopRecognition();
      cleanupRecording();
      stopPlayback();
      assistantOutput.clearTimers();
    },
    [],
  );

  const activePhase: AssistantPhase =
    listeningMode === "wake" || listeningMode === "command"
      ? "listening"
      : isAudioSpeaking || phase === "speaking"
        ? "speaking"
        : phase;

  return (
    <div className="jarvis-shell">
      <div className="jarvis-shell__ambient jarvis-shell__ambient--cyan" />
      <div className="jarvis-shell__ambient jarvis-shell__ambient--orange" />

      <main
        className={`jarvis-layout ${isChatCollapsed ? "is-chat-collapsed" : ""}`}
      >
        <aside className="chat-panel" aria-label="Assistant chat">
          {hasStarted ? (
            <>
              <div
                ref={logRef}
                className="chat-log"
                role="log"
                aria-live="polite"
                onScroll={(event) => {
                  const element = event.currentTarget;
                  const distanceFromBottom =
                    element.scrollHeight - element.scrollTop - element.clientHeight;
                  shouldStickToBottomRef.current = distanceFromBottom < 48;
                }}
              >
                {isBooting ? (
                  <article className="message-bubble message-bubble--assistant message-bubble--loading">
                    <span className="message-bubble__role">JARVIS</span>
                    <p>Preparing your startup briefing...</p>
                  </article>
                ) : null}

                {messages.map((message) => (
                  <article
                    key={message.id}
                    className={`message-bubble message-bubble--${message.role}`}
                  >
                    <span className="message-bubble__role">
                      {message.role === "assistant" ? "JARVIS" : "You"}
                    </span>
                    <p>{message.text}</p>
                  </article>
                ))}
              </div>

              {!isBooting ? (
                <form
                  className="composer"
                  onSubmit={(event) => {
                    event.preventDefault();
                    void submitPrompt(draft);
                  }}
                >
                  <div className="composer__actions">
                    <input
                      ref={inputRef}
                      id="jarvis-prompt"
                      value={draft}
                      onChange={(event) => setDraft(event.target.value)}
                      className="composer__input"
                      placeholder="Speak or type your next instruction..."
                    />
                    <button
                      className={`composer__mic ${listeningMode === "command" ? "is-active" : ""}`}
                      type="button"
                      aria-pressed={listeningMode === "command"}
                      aria-label={
                        listeningMode === "command"
                          ? "Stop microphone session"
                          : "Start microphone session"
                      }
                      onClick={() => {
                        if (listeningMode === "command") {
                          const recorder = mediaRecorderRef.current;
                          if (recorder && recorder.state !== "inactive") {
                            recorder.stop();
                          } else {
                            cleanupRecording();
                            setListeningMode(null);
                            setDraft("");
                            setPhase("idle");
                          }
                          return;
                        }
                        void startCommandListening();
                      }}
                    >
                      <Mic size={18} />
                    </button>
                    <button className="composer__submit" type="submit">
                      Send
                    </button>
                  </div>
                </form>
              ) : null}
            </>
          ) : (
            <div className="chat-launcher">
              <button
                className="chat-launcher__button"
                type="button"
                aria-label="Start Jarvis greeting"
                onClick={() => void startAssistant()}
              >
                <span className="chat-launcher__core" />
              </button>
            </div>
          )}
        </aside>

        <section className="sphere-stage" aria-label="Assistant visualization">
          <button
            className="panel-toggle panel-toggle--floating"
            type="button"
            onClick={() => setIsChatCollapsed((current) => !current)}
            aria-label={isChatCollapsed ? "Open chat panel" : "Collapse chat panel"}
          >
            {isChatCollapsed ? (
              <ChevronRight size={18} />
            ) : (
              <ChevronLeft size={18} />
            )}
          </button>

          <div className="sphere-frame">
            <div className={`phase-pill phase-pill--${activePhase}`}>
              {activePhase}
            </div>

            <div className={`assistant-sphere assistant-sphere--${activePhase}`}>
              <AssistantSphere phase={activePhase} />
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
