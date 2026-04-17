import { NextResponse } from "next/server";
import { buildNajeongyeonAdminSummary } from "../../../../team/najeongyeon-admin";

export async function GET() {
  const snapshot = await buildNajeongyeonAdminSummary();

  return NextResponse.json(snapshot);
}
