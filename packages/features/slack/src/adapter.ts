import { isMockMode } from "@jarvis/shared";
import type { SlackDigest } from "@jarvis/shared";
import { mockSlackDigest } from "./mock";

export interface SlackClient {
  getWorkspaceDigest: (input: {
    query: string;
    date: string;
  }) => Promise<SlackDigest>;
}

export function createMockSlackClient(): SlackClient {
  return {
    async getWorkspaceDigest(_input) {
      return mockSlackDigest;
    }
  };
}

function createLiveSlackClient(): SlackClient {
  return {
    async getWorkspaceDigest(_input) {
      throw new Error(
        "Live Slack client is not implemented yet. Update packages/features/slack/src/adapter.ts."
      );
    }
  };
}

export function getSlackClient() {
  return isMockMode() ? createMockSlackClient() : createLiveSlackClient();
}
