import { NextResponse } from "next/server";
import { isMockMode } from "../../../team/common";

export async function GET() {
  return NextResponse.json({
    status: "ok",
    mode: isMockMode() ? "mock" : "live"
  });
}
