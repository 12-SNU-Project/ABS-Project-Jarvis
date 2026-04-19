import axios from "axios";

import type { SlackSummaryRequest, SlackSummaryResponse } from "../types/slack";

const API_BASE_URL = import.meta.env.VITE_API_URL || "http://localhost:8000";

const api = axios.create({
  baseURL: API_BASE_URL,
});

export const slackApi = {
  getSlackSummary: async (
    params: SlackSummaryRequest,
  ): Promise<SlackSummaryResponse> => {
    const response = await api.post<SlackSummaryResponse>("/api/v1/slack/summary", params);
    return response.data;
  },
};
