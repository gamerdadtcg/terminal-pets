import {
  createPublicClient,
  getAddress,
  http,
  isAddress,
  type Address,
  type PublicClient,
} from "viem";
import {
  ALL_PARTNERS,
  ERC721_BALANCE_ABI,
  type PartnerPhase,
} from "@/lib/allowlist-partners";
import { ROBINHOOD_CHAIN_ID, ROBINHOOD_RPC, robinhoodChain } from "@/lib/chain";
import { mintSchedule, SITE } from "@/lib/site";

export type PartnerHolding = {
  name: string;
  address: Address;
  phase: PartnerPhase;
  balance: string;
};

export type EligibilityResult = {
  address: Address;
  chainId: typeof ROBINHOOD_CHAIN_ID;
  gtd: boolean;
  fcfs: boolean;
  public: true;
  holdings: PartnerHolding[];
  failed: Array<{
    name: string;
    address: Address;
    phase: PartnerPhase;
  }>;
};

export type EligibilityFailure = {
  ok: false;
  error: "invalid_address" | "rpc_failed";
  message: string;
};

export type EligibilityCheck =
  | { ok: true; result: EligibilityResult }
  | EligibilityFailure;

const publicPhase = mintSchedule.phases.find((phase) => phase.name === "Public");
const gtdPhase = mintSchedule.phases.find((phase) => phase.name === "GTD");
const fcfsPhase = mintSchedule.phases.find((phase) => phase.name === "FCFS");

export const ELIGIBILITY_COPY = {
  publicNote: `Public phase is open to everyone (no allowlist) ${publicPhase?.time ?? "Friday 10:00 AM PT"}.`,
  schedule: `${mintSchedule.date} · ${mintSchedule.timezoneIana} (${mintSchedule.timezoneLabel}): ${gtdPhase?.time ?? "8:00 AM PT"} GTD · ${fcfsPhase?.time ?? "9:00 AM PT"} FCFS · ${publicPhase?.time ?? "10:00 AM PT"} Public. ${mintSchedule.perPhase} per phase.`,
  disclaimer:
    "Eligibility is current on-chain holdings. Final mint gating may also require mintOpen and the phase window on mint day. Partner lists may grow before lock. This is not a Merkle allowlist — CollectionNFT currently gates on mintOpen only.",
  invalidAddress:
    "That doesn't look like a wallet address. Paste a 0x… Ethereum address.",
} as const;

/** Always Robinhood mainnet — partner NFTs live on 4663, not the dry-run chain. */
export function partnerHoldingsRpc(): string {
  return (
    process.env.ROBINHOOD_RPC_URL?.trim() ||
    process.env.NEXT_PUBLIC_ROBINHOOD_RPC_URL?.trim() ||
    SITE.rpc ||
    ROBINHOOD_RPC
  );
}

export function parseWalletAddress(value: string): Address | null {
  const trimmed = value.trim();
  if (!isAddress(trimmed)) return null;
  return getAddress(trimmed);
}

let client: PublicClient | undefined;

function robinhoodPublicClient(): PublicClient {
  if (!client) {
    client = createPublicClient({
      chain: robinhoodChain,
      transport: http(partnerHoldingsRpc(), { timeout: 20_000 }),
    });
  }
  return client;
}

export async function checkPartnerEligibility(
  wallet: string,
): Promise<EligibilityCheck> {
  const address = parseWalletAddress(wallet);
  if (!address) {
    return {
      ok: false,
      error: "invalid_address",
      message: ELIGIBILITY_COPY.invalidAddress,
    };
  }

  const rpc = partnerHoldingsRpc();
  const publicClient = robinhoodPublicClient();

  const reads = await Promise.all(
    ALL_PARTNERS.map(async (partner) => {
      try {
        const balance = await publicClient.readContract({
          address: partner.address,
          abi: ERC721_BALANCE_ABI,
          functionName: "balanceOf",
          args: [address],
        });
        return { partner, balance, ok: true as const };
      } catch {
        return { partner, balance: 0n, ok: false as const };
      }
    }),
  );

  if (reads.every((read) => !read.ok)) {
    return {
      ok: false,
      error: "rpc_failed",
      message: `Could not reach Robinhood Chain RPC (${rpc}). Try again in a moment.`,
    };
  }

  const holdings: PartnerHolding[] = [];
  const failed: EligibilityResult["failed"] = [];

  for (const read of reads) {
    if (!read.ok) {
      failed.push({
        name: read.partner.name,
        address: read.partner.address,
        phase: read.partner.phase,
      });
      continue;
    }
    if (read.balance > 0n) {
      holdings.push({
        name: read.partner.name,
        address: read.partner.address,
        phase: read.partner.phase,
        balance: read.balance.toString(),
      });
    }
  }

  return {
    ok: true,
    result: {
      address,
      chainId: ROBINHOOD_CHAIN_ID,
      gtd: holdings.some((holding) => holding.phase === "GTD"),
      fcfs: holdings.some((holding) => holding.phase === "FCFS"),
      public: true,
      holdings,
      failed,
    },
  };
}
