import type { SlackDigest, UserContext } from "@jarvis/shared";
import type { SlackClient } from "./adapter";
import { getSlackClient } from "./adapter";

export async function getSlackDigest(
  context: UserContext,
  client: SlackClient = getSlackClient()
): Promise<SlackDigest> {
  return client.getWorkspaceDigest({
    query: context.userInput,
    date: context.date
  });
}
