import axios from "axios";
import { API_BASE_URL } from "../../../lib/config";

import type { SlackSummaryRequest, SlackSummaryResponse } from "../types/slack";

const api = axios.create({
  baseURL: API_BASE_URL,
});

export const slackApi = {
  getSlackSummary: async (
    params: SlackSummaryRequest,
  ): Promise<SlackSummaryResponse> => {
    const response = await api.post<SlackSummaryResponse>("/slack/summary", params);
    return response.data;
  },
};
