const ISO_DATE = "\\d{4}-\\d{2}-\\d{2}";
const TIME = "\\d{2}:\\d{2}";

export interface ParseContext {
  defaultDate: string;
  defaultCalendarId: string;
  latestProposalId?: string;
}

export interface PendingEventDraft {
  calendarId: string;
  date: string;
  startTime?: string;
  title?: string;
  durationMinutes?: number;
  location?: string;
  needsZoomDetails?: boolean;
  priority?: string;
}

export type AgentAction =
  | { kind: "help" }
  | { kind: "refresh" }
  | { kind: "showCalendars" }
  | { kind: "inspectCalendar"; calendarId: string }
  | { kind: "showEvents"; calendarId: string; date: string }
  | { kind: "showConflicts"; calendarId: string; date: string }
  | { kind: "showSummary"; calendarId: string; date: string }
  | { kind: "showProposals" }
  | { kind: "showProposal"; proposalId: string }
  | { kind: "showAudit" }
  | { kind: "showBriefing"; date: string }
  | {
      kind: "createCalendar";
      payload: {
        operation_type: "create_calendar";
        actor: "agent-ui";
        calendar: { name: string; timezone?: string };
      };
    }
  | {
      kind: "deleteCalendar";
      payload: {
        operation_type: "delete_calendar";
        actor: "agent-ui";
        calendar_id: string;
      };
    }
  | {
      kind: "createProposal";
      payload: Record<string, unknown>;
      summary: string;
    }
  | { kind: "executeProposal"; proposalId: string }
  | { kind: "rejectProposal"; proposalId: string };

export const HELP_TEXT = `Supported commands:

- show calendars
- inspect calendar <calendar_id>
- show schedule for <YYYY-MM-DD>
- show conflicts for <YYYY-MM-DD>
- show summary for <YYYY-MM-DD>
- show proposals
- show proposal <proposal_id>
- show audit
- show briefing for <YYYY-MM-DD>
- create calendar "<name>" [timezone <IANA timezone>]
- delete calendar <calendar_id>
- create event "<title>" on <YYYY-MM-DD> from <HH:MM> to <HH:MM> [at "<location>"] [priority high|medium|low] [calendar <id>]
- update event <event_id> title "<title>" [location "<location>"] [priority high|medium|low] [calendar <id>]
- move event <event_id> to <YYYY-MM-DD> from <HH:MM> to <HH:MM> [scope occurrence|following|series] [calendar <id>]
- delete event <event_id> [scope occurrence|following|series] [calendar <id>]
- execute <proposal_id|latest>
- reject <proposal_id|latest>
- refresh`;

function capture(command: string, pattern: RegExp): RegExpExecArray | null {
  return pattern.exec(command.trim());
}

function option(command: string, pattern: RegExp): string | undefined {
  return pattern.exec(command)?.[1];
}

function buildIso(date: string, time: string): string {
  return `${date}T${time}:00+09:00`;
}

function shiftIsoDate(date: string, days: number): string {
  const [year, month, day] = date.split("-").map(Number);
  const shifted = new Date(Date.UTC(year, month - 1, day));
  shifted.setUTCDate(shifted.getUTCDate() + days);
  return shifted.toISOString().slice(0, 10);
}

function getLocalDate(): string {
  return new Intl.DateTimeFormat("en-CA", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
}

function inferNaturalReadAction(
  command: string,
  context: ParseContext,
): AgentAction | null {
  const lower = command.toLowerCase();
  const normalized = lower.replace(/[?.!,]/g, " ").replace(/\s+/g, " ").trim();
  const todayWords =
    /\btoday\b|\bthis morning\b|\bthis afternoon\b|\bthis evening\b/;
  const scheduleWords =
    /\b(meeting|meetings|schedule|calendar|agenda|appointments|appointment)\b/;
  const conflictWords =
    /\b(conflict|conflicts|overlap|overlaps|collide|collision)\b/;
  const summaryWords = /\b(summary|summarize|overview|brief me|briefing)\b/;
  const briefingWords = /\bbriefing\b|\bbrief me\b/;
  const explicitCalendar = /\bcalendar\s+(\S+)\b/i.exec(command)?.[1];
  const date = todayWords.test(lower) ? getLocalDate() : context.defaultDate;
  const calendarId = explicitCalendar ?? context.defaultCalendarId;

  if (
    /\bcalendars\b/.test(normalized) &&
    /\b(show|list|available|what are|what's|what is|tell me)\b/.test(normalized)
  ) {
    return { kind: "showCalendars" };
  }

  if (briefingWords.test(lower) && scheduleWords.test(lower)) {
    return { kind: "showBriefing", date };
  }

  if (conflictWords.test(lower) && scheduleWords.test(lower)) {
    return { kind: "showConflicts", calendarId, date };
  }

  if (summaryWords.test(lower) && scheduleWords.test(lower)) {
    return { kind: "showSummary", calendarId, date };
  }

  if (
    scheduleWords.test(lower) &&
    /\b(what|which|when|do i have|have i got|what's on|whats on|list)\b/.test(
      lower,
    )
  ) {
    return { kind: "showEvents", calendarId, date };
  }

  return null;
}

function normalizeClockValue(value: string): string | null {
  const trimmed = value.trim().toLowerCase().replace(/\s+/g, "");
  const match = trimmed.match(/^(\d{1,2})(?::(\d{2}))?(am|pm)?$/i);
  if (!match) {
    return null;
  }

  let hour = Number(match[1]);
  const minute = Number(match[2] ?? "00");
  const meridiem = match[3];

  if (Number.isNaN(hour) || Number.isNaN(minute) || minute > 59) {
    return null;
  }

  if (meridiem) {
    if (hour < 1 || hour > 12) {
      return null;
    }
    if (meridiem === "am") {
      hour = hour === 12 ? 0 : hour;
    } else {
      hour = hour === 12 ? 12 : hour + 12;
    }
  } else if (hour > 23) {
    return null;
  }

  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

function extractTimeFromText(value: string): string | undefined {
  const explicitTime =
    value.match(/\b(\d{1,2}:\d{2}\s*(?:am|pm)?|\d{1,2}\s*(?:am|pm))\b/i)?.[1] ??
    value.match(/\b(?:at|from|on)\s+(\d{1,2})(?!\.\d)\b/i)?.[1];

  if (!explicitTime) {
    return undefined;
  }

  return normalizeClockValue(explicitTime) ?? undefined;
}

function addDuration(date: string, time: string, minutes: number): {
  date: string;
  time: string;
} {
  const [year, month, day] = date.split("-").map(Number);
  const [hour, minute] = time.split(":").map(Number);
  const start = new Date(Date.UTC(year, month - 1, day, hour, minute));
  start.setUTCMinutes(start.getUTCMinutes() + minutes);

  return {
    date: start.toISOString().slice(0, 10),
    time: `${String(start.getUTCHours()).padStart(2, "0")}:${String(
      start.getUTCMinutes(),
    ).padStart(2, "0")}`,
  };
}

function toTitleCase(value: string): string {
  return value.replace(/\b([a-z])/g, (match) => match.toUpperCase());
}

function cleanDraftTitleCandidate(value: string): string {
  return value
    .replace(
      /\b(?:and\s+)?(?:\d+(?:\.\d+)?\s*(?:minutes|minute|mins|min|hours|hour|hrs|hr)|no link|none|no zoom link|here is the zoom link|zoom link|link[:\s].*|https?:\/\/\S+)\b.*$/i,
      "",
    )
    .replace(/[.,]+$/g, "")
    .trim();
}

function isGenericMeetingTitle(value: string): boolean {
  return /^(meeting|call|appointment|event)$/i.test(value.trim());
}

function extractNaturalEventDraft(
  command: string,
  context: ParseContext,
): PendingEventDraft | null {
  const prefixMatch = command.match(
    /^(?:i have|i've got|add|create|schedule)\s+(.+)$/i,
  );
  if (!prefixMatch) {
    return null;
  }

  const body = prefixMatch[1].trim();
  const timeMatch = body.match(
    /\b(?:at|on)\s+(\d{1,2}(?::\d{2})?\s*(?:am|pm)?|\d{1,2}:\d{2})\b/i,
  );
  const startTime = timeMatch
    ? normalizeClockValue(timeMatch[1]) ?? undefined
    : undefined;
  if (timeMatch && !startTime) {
    return null;
  }

  let date = context.defaultDate;
  if (/\btomorrow\b/i.test(body)) {
    date = shiftIsoDate(context.defaultDate, 1);
  } else if (/\byesterday\b/i.test(body)) {
    date = shiftIsoDate(context.defaultDate, -1);
  } else if (/\btoday\b/i.test(body)) {
    date = getLocalDate();
  }

  const locationMatch = timeMatch
    ? body
        .slice((timeMatch.index ?? 0) + timeMatch[0].length)
        .match(/\b(?:via|at|in)\s+"?([A-Za-z0-9][^"]*?)"?\s*$/i)
    : body.match(/\b(?:via|at|in)\s+"?([A-Za-z0-9][^"]*?)"?\s*$/i);

  const genericTitle = body
    .replace(/\b(today|tomorrow|yesterday)\b/gi, "")
    .replace(/\b(?:in|on)\s+the\s+(morning|afternoon|evening|night)\b/gi, "")
    .replace(/\b(this\s+)?(morning|afternoon|evening|night)\b/gi, "")
    .replace(
      /\b(?:at|on)\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b/gi,
      "",
    )
    .replace(/\b(?:via|at|in)\s+"?([A-Za-z0-9][^"]*?)"?\s*$/i, "")
    .replace(/^(?:a|an)\s+/i, "")
    .trim()
    .replace(/[.,]+$/g, "");
  const title = genericTitle ? toTitleCase(genericTitle) : undefined;
  const location = locationMatch?.[1]?.trim().replace(/[.,]+$/g, "");
  const calendarId =
    option(body, /\bcalendar (\S+)\b/i) ?? context.defaultCalendarId;
  const priority = option(body, /\bpriority (high|medium|low)\b/i);
  const needsZoomDetails = /\bzoom\b/i.test(location ?? "");

  return {
    calendarId,
    date,
    startTime,
    title: title && !isGenericMeetingTitle(title) ? title : undefined,
    location,
    needsZoomDetails,
    priority,
  };
}

export function inferPendingEventDraft(
  command: string,
  context: ParseContext,
): PendingEventDraft | null {
  return extractNaturalEventDraft(command, context);
}

function extractDurationMinutes(input: string): number | undefined {
  const match = input.match(
    /\b(\d+(?:\.\d+)?)\s*(minutes|minute|mins|min|hours|hour|hrs|hr)\b/i,
  );
  if (!match) {
    return undefined;
  }

  const value = Number(match[1]);
  if (Number.isNaN(value) || value <= 0) {
    return undefined;
  }

  return Math.round(/hour|hr/i.test(match[2]) ? value * 60 : value);
}

function extractDraftTitle(input: string): string | undefined {
  const quoted =
    input.match(/\b(?:name it|call it|title it|title)\s+"([^"]+)"/i)?.[1] ??
    input.match(/^"([^"]+)"$/)?.[1];
  if (quoted) {
    return cleanDraftTitleCandidate(quoted);
  }

  const named = input.match(/\b(?:name it|call it|title it|title)\s+(.+)$/i)?.[1];
  if (named) {
    return cleanDraftTitleCandidate(named);
  }

  const leadingSegment = input.split(",")[0]?.trim();
  if (
    leadingSegment &&
    leadingSegment.split(/\s+/).length <= 6 &&
    !/\b(minutes|minute|mins|min|hours|hour|hrs|hr|zoom|http|link|id)\b/i.test(
      leadingSegment,
    )
  ) {
    return cleanDraftTitleCandidate(leadingSegment);
  }

  const plain = input.trim();
  if (
    plain &&
    plain.split(/\s+/).length <= 5 &&
    !/\b(minutes|minute|mins|min|hours|hour|hrs|hr|zoom|http|link|id)\b/i.test(
      plain,
    )
  ) {
    return cleanDraftTitleCandidate(plain);
  }

  return undefined;
}

function extractLocationUpdate(input: string): {
  location?: string;
  needsZoomDetails?: boolean;
} {
  if (/\b(no|none|nope)\b.*\b(link|id|zoom)\b/i.test(input)) {
    return { needsZoomDetails: false };
  }

  const url = input.match(/https?:\/\/\S+/i)?.[0];
  if (url) {
    return { location: url, needsZoomDetails: false };
  }

  const zoomId =
    input.match(/\b(?:zoom|meeting)\s*id[:\s#-]*([A-Za-z0-9 -]+)/i)?.[1];
  if (zoomId) {
    return {
      location: `Zoom ID ${zoomId.trim().replace(/[.,]+$/g, "")}`,
      needsZoomDetails: false,
    };
  }

  const link = input.match(/\b(?:link|via|at|in)\s+"?([^"]+)"?$/i)?.[1];
  if (link) {
    const cleaned = link.trim().replace(/[.,]+$/g, "");
    return {
      location: cleaned,
      needsZoomDetails: !/https?:\/\//i.test(cleaned) && /\bzoom\b/i.test(cleaned),
    };
  }

  return {};
}

export function continuePendingEventDraft(
  input: string,
  draft: PendingEventDraft,
): PendingEventDraft {
  const nextDraft: PendingEventDraft = { ...draft };
  const title = extractDraftTitle(input);
  const durationMinutes = extractDurationMinutes(input);
  const startTime = extractTimeFromText(input);
  const locationUpdate = extractLocationUpdate(input);

  if (title) {
    nextDraft.title = title;
  }
  if (durationMinutes) {
    nextDraft.durationMinutes = durationMinutes;
  }
  if (startTime) {
    nextDraft.startTime = startTime;
  }
  if (locationUpdate.location) {
    nextDraft.location = locationUpdate.location;
  }
  if (locationUpdate.needsZoomDetails !== undefined) {
    nextDraft.needsZoomDetails = locationUpdate.needsZoomDetails;
  }

  return nextDraft;
}

export function buildEventDraftPrompt(draft: PendingEventDraft): string {
  const questions: string[] = [];

  if (!draft.startTime) {
    questions.push("What time should I place it?");
  }
  if (!draft.title) {
    questions.push("What should I name it?");
  }
  if (!draft.durationMinutes) {
    questions.push("How long is the meeting?");
  }
  if (draft.needsZoomDetails) {
    questions.push("Do you have any specific Zoom ID or link?");
  }

  const opening =
    questions.length > 0
      ? "Understood. I'll prepare that event on your calendar."
      : "Okay, I have enough detail to draft the event.";

  return [opening, ...questions].join(" ");
}

export function buildCreateProposalFromDraft(
  draft: PendingEventDraft,
): AgentAction {
  const title = draft.title?.trim() || "Meeting";
  const durationMinutes = draft.durationMinutes ?? 60;
  const startTime = draft.startTime ?? "09:00";
  const end = addDuration(draft.date, startTime, durationMinutes);

  return {
    kind: "createProposal",
    summary: `Draft create_event proposal for "${title}".`,
    payload: {
      operation_type: "create_event",
      actor: "agent-ui",
      calendar_id: draft.calendarId,
      event: {
        title,
        start: buildIso(draft.date, startTime),
        end: buildIso(end.date, end.time),
        location: draft.location,
        priority: draft.priority,
      },
    },
  };
}

export function isEventDraftComplete(draft: PendingEventDraft): boolean {
  return Boolean(
    draft.startTime &&
      draft.title &&
      draft.durationMinutes &&
      (!draft.needsZoomDetails || draft.location),
  );
}

export function parseCommand(
  input: string,
  context: ParseContext,
): AgentAction | null {
  const command = input.trim();
  const lower = command.toLowerCase();

  if (!command || lower === "help") {
    return { kind: "help" };
  }
  if (lower === "refresh") {
    return { kind: "refresh" };
  }
  if (lower === "show calendars") {
    return { kind: "showCalendars" };
  }
  if (lower === "show proposals") {
    return { kind: "showProposals" };
  }
  if (lower === "show audit") {
    return { kind: "showAudit" };
  }

  const inferredRead = inferNaturalReadAction(command, context);
  if (inferredRead) {
    return inferredRead;
  }

  const inspectCalendar = capture(command, /^inspect calendar (\S+)$/i);
  if (inspectCalendar) {
    return { kind: "inspectCalendar", calendarId: inspectCalendar[1] };
  }

  const showProposal = capture(command, /^show proposal (\S+)$/i);
  if (showProposal) {
    return { kind: "showProposal", proposalId: showProposal[1] };
  }

  const readPattern =
    /^show (schedule|events|conflicts|summary|briefing)(?: for (\d{4}-\d{2}-\d{2}))?(?: calendar (\S+))?$/i;
  const readMatch = capture(command, readPattern);
  if (readMatch) {
    const kind = readMatch[1].toLowerCase();
    const date = readMatch[2] ?? context.defaultDate;
    const calendarId = readMatch[3] ?? context.defaultCalendarId;
    if (kind === "conflicts") {
      return { kind: "showConflicts", calendarId, date };
    }
    if (kind === "summary") {
      return { kind: "showSummary", calendarId, date };
    }
    if (kind === "briefing") {
      return { kind: "showBriefing", date };
    }
    return { kind: "showEvents", calendarId, date };
  }

  const execute = capture(command, /^execute (\S+)$/i);
  if (execute) {
    return {
      kind: "executeProposal",
      proposalId:
        execute[1] === "latest" ? context.latestProposalId ?? "latest" : execute[1],
    };
  }

  const reject = capture(command, /^reject (\S+)$/i);
  if (reject) {
    return {
      kind: "rejectProposal",
      proposalId:
        reject[1] === "latest" ? context.latestProposalId ?? "latest" : reject[1],
    };
  }

  const createCalendar = capture(
    command,
    /^create calendar "([^"]+)"(?: timezone ([A-Za-z_./-]+))?$/i,
  );
  if (createCalendar) {
    return {
      kind: "createCalendar",
      payload: {
        operation_type: "create_calendar",
        actor: "agent-ui",
        calendar: {
          name: createCalendar[1],
          timezone: createCalendar[2] ?? "Asia/Seoul",
        },
      },
    };
  }

  const deleteCalendar = capture(command, /^delete calendar (\S+)$/i);
  if (deleteCalendar) {
    return {
      kind: "deleteCalendar",
      payload: {
        operation_type: "delete_calendar",
        actor: "agent-ui",
        calendar_id: deleteCalendar[1],
      },
    };
  }

  const createEvent = capture(
    command,
    new RegExp(
      `^create event "([^"]+)" on (${ISO_DATE}) from (${TIME}) to (${TIME})(.*)$`,
      "i",
    ),
  );
  if (createEvent) {
    const tail = createEvent[5];
    const location = option(tail, /at "([^"]+)"/i);
    const priority = option(tail, /priority (high|medium|low)/i);
    const calendarId =
      option(tail, /calendar (\S+)/i) ?? context.defaultCalendarId;
    return {
      kind: "createProposal",
      summary: `Draft create_event proposal for "${createEvent[1]}".`,
      payload: {
        operation_type: "create_event",
        actor: "agent-ui",
        calendar_id: calendarId,
        event: {
          title: createEvent[1],
          start: buildIso(createEvent[2], createEvent[3]),
          end: buildIso(createEvent[2], createEvent[4]),
          location,
          priority,
        },
      },
    };
  }

  const updateEvent = capture(command, /^update event (\S+) title "([^"]+)"(.*)$/i);
  if (updateEvent) {
    const tail = updateEvent[3];
    const location = option(tail, /location "([^"]+)"/i);
    const priority = option(tail, /priority (high|medium|low)/i);
    const calendarId =
      option(tail, /calendar (\S+)/i) ?? context.defaultCalendarId;
    return {
      kind: "createProposal",
      summary: `Draft update_event proposal for ${updateEvent[1]}.`,
      payload: {
        operation_type: "update_event",
        actor: "agent-ui",
        calendar_id: calendarId,
        event_id: updateEvent[1],
        event: {
          title: updateEvent[2],
          location,
          priority,
        },
      },
    };
  }

  const moveEvent = capture(
    command,
    new RegExp(
      `^move event (\\S+) to (${ISO_DATE}) from (${TIME}) to (${TIME})(.*)$`,
      "i",
    ),
  );
  if (moveEvent) {
    const tail = moveEvent[5];
    const scope = option(tail, /scope (occurrence|following|series)/i);
    const calendarId =
      option(tail, /calendar (\S+)/i) ?? context.defaultCalendarId;
    return {
      kind: "createProposal",
      summary: `Draft move_event proposal for ${moveEvent[1]}.`,
      payload: {
        operation_type: "move_event",
        actor: "agent-ui",
        calendar_id: calendarId,
        event_id: moveEvent[1],
        recurring_scope: scope,
        event: {
          start: buildIso(moveEvent[2], moveEvent[3]),
          end: buildIso(moveEvent[2], moveEvent[4]),
        },
      },
    };
  }

  const deleteEvent = capture(command, /^delete event (\S+)(.*)$/i);
  if (deleteEvent) {
    const tail = deleteEvent[2];
    const scope = option(tail, /scope (occurrence|following|series)/i);
    const calendarId =
      option(tail, /calendar (\S+)/i) ?? context.defaultCalendarId;
    return {
      kind: "createProposal",
      summary: `Draft delete_event proposal for ${deleteEvent[1]}.`,
      payload: {
        operation_type: "delete_event",
        actor: "agent-ui",
        calendar_id: calendarId,
        event_id: deleteEvent[1],
        recurring_scope: scope,
      },
    };
  }

  return null;
}
