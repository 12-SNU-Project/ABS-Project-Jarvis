export type SlackSummaryRequest = {
  channel_id: string;
  user_input: string;
  date: string;
  lookback_hours: number;
};

export type SlackMessage = {
  user: string;
  text: string;
  ts: string;
};

export type SlackSummaryResponse = {
  owner: string;
  feature: string;
  uses_mock: boolean;
  date: string;
  channel_id: string;
  channel_name: string;
  lookback_hours: number;
  message_count: number;
  summary: string;
  summary_lines: string[];
  messages: SlackMessage[];
  model: string;
};
