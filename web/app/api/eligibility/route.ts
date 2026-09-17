import { isLiveArcadeGtdWallet } from "@/lib/arcade-store";
import { checkPartnerEligibility } from "@/lib/eligibility";
import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

async function respond(address: string) {
  const checked = await checkPartnerEligibility(address);
  if (!checked.ok) {
    const status = checked.error === "invalid_address" ? 400 : 502;
    return NextResponse.json(
      { error: checked.error, message: checked.message },
      { status },
    );
  }
  let arcadeGtd = checked.result.arcadeGtd;
  try {
    arcadeGtd = arcadeGtd || (await isLiveArcadeGtdWallet(checked.result.address));
  } catch {
    // Exported arcade list still applies if the live board is down.
  }
  const gtd = checked.result.gtd || arcadeGtd;
  return NextResponse.json(
    {
      ...checked.result,
      arcadeGtd,
      gtd,
      fcfs: checked.result.fcfs || gtd,
      fcfsViaGtd: gtd,
    },
    {
      headers: { "Cache-Control": "no-store" },
    },
  );
}

export async function GET(request: Request) {
  const address = new URL(request.url).searchParams.get("address") ?? "";
  return respond(address);
}

export async function POST(request: Request) {
  let address = "";
  try {
    const body = (await request.json()) as { address?: unknown };
    if (typeof body.address === "string") address = body.address;
  } catch {
    address = "";
  }
  return respond(address);
}
