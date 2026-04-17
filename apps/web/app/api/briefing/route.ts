import { NextResponse } from "next/server";
import { runMorningBriefing } from "../../../team/baemingyu-orchestrator";
import type { BriefingInput } from "../../../team/common";

export async function GET() {
  const result = await runMorningBriefing();

  return NextResponse.json(result);
}

export async function POST(request: Request) {
  const payload = (await request.json()) as Partial<BriefingInput>;
  const result = await runMorningBriefing(payload);

  return NextResponse.json(result);
}
