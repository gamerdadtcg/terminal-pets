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
  type PartnerCollection,
  type PartnerPhase,
} from "@/lib/allowlist-partners";
import {
  ETHEREUM_CHAIN_ID,
  ETHEREUM_RPC,
  ROBINHOOD_CHAIN_ID,
  ROBINHOOD_RPC,
  mainnet,
  robinhoodChain,
} from "@/lib/chain";
import { isManualGtdWallet } from "@/lib/manual-gtd-wallets";
import { mintSchedule, SITE } from "@/lib/site";

export type PartnerHolding = {
  name: string;
  address: Address;
  phase: PartnerPhase;
  balance: string;
  chainId: number;
};

export type EligibilityResult = {
  address: Address;
  chainId: typeof ROBINHOOD_CHAIN_ID;
  gtd: boolean;
  fcfs: boolean;
  public: true;
  /** True if this wallet is on the GTD X-thread manual list. Hub preview only. */
  manualGtd: boolean;
  /**
   * True when FCFS is yes because this wallet is GTD-eligible (partner NFT
   * and/or thread list). Shown even if the wallet also holds FCFS NFTs.
   */
  fcfsViaGtd: boolean;
  holdings: PartnerHolding[];
  failed: Array<{
    name: string;
    address: Address;
    phase: PartnerPhase;
    chainId: number;
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
    "Eligibility is current on-chain holdings plus the GTD X-thread wallet list. GTD-eligible wallets also unlock FCFS. Hub preview only — CollectionNFT still gates mint on mintOpen. Not an on-chain mint allowlist until Travis locks mint phase. Partner lists may grow before lock.",
  fcfsViaGtd: "Included via GTD eligibility",
  invalidAddress:
    "That doesn't look like a wallet address. Paste a 0x… Ethereum address.",
} as const;

/** UI / API reason when FCFS is yes because the wallet is GTD-eligible. */
export const FCFS_VIA_GTD_REASON = ELIGIBILITY_COPY.fcfsViaGtd;

function partnerChainId(partner: PartnerCollection): number {
  return partner.chainId ?? ROBINHOOD_CHAIN_ID;
}

/** Robinhood mainnet — default partner NFTs live on 4663, not the dry-run chain. */
export function partnerHoldingsRpc(): string {
  return (
    process.env.ROBINHOOD_RPC_URL?.trim() ||
    process.env.NEXT_PUBLIC_ROBINHOOD_RPC_URL?.trim() ||
    SITE.rpc ||
    ROBINHOOD_RPC
  );
}

/** Ethereum mainnet — School of NFTs and other chainId 1 exceptions. */
export function ethereumHoldingsRpc(): string {
  return (
    process.env.ETHEREUM_RPC_URL?.trim() ||
    process.env.NEXT_PUBLIC_ETHEREUM_RPC_URL?.trim() ||
    ETHEREUM_RPC
  );
}

export function parseWalletAddress(value: string): Address | null {
  const trimmed = value.trim();
  // Non-strict: accept any 0x + 40 hex regardless of EIP-55 checksum so
  // manual GTD lookup can be case-insensitive.
  if (!isAddress(trimmed, { strict: false })) return null;
  return getAddress(trimmed.toLowerCase());
}

let robinhoodClient: PublicClient | undefined;
let ethereumClient: PublicClient | undefined;

function robinhoodPublicClient(): PublicClient {
  if (!robinhoodClient) {
    robinhoodClient = createPublicClient({
      chain: robinhoodChain,
      transport: http(partnerHoldingsRpc(), { timeout: 20_000 }),
    });
  }
  return robinhoodClient;
}

function ethereumPublicClient(): PublicClient {
  if (!ethereumClient) {
    ethereumClient = createPublicClient({
      chain: mainnet,
      transport: http(ethereumHoldingsRpc(), { timeout: 20_000 }),
    });
  }
  return ethereumClient;
}

function publicClientForPartner(partner: PartnerCollection): PublicClient {
  return partnerChainId(partner) === ETHEREUM_CHAIN_ID
    ? ethereumPublicClient()
    : robinhoodPublicClient();
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

  const manualGtd = isManualGtdWallet(address);

  const reads = await Promise.all(
    ALL_PARTNERS.map(async (partner) => {
      try {
        const balance = await publicClientForPartner(partner).readContract({
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

  if (reads.every((read) => !read.ok) && !manualGtd) {
    return {
      ok: false,
      error: "rpc_failed",
      message:
        "Could not reach partner NFT RPCs (Robinhood Chain and/or Ethereum). Try again in a moment.",
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
        chainId: partnerChainId(read.partner),
      });
      continue;
    }
    if (read.balance > 0n) {
      holdings.push({
        name: read.partner.name,
        address: read.partner.address,
        phase: read.partner.phase,
        balance: read.balance.toString(),
        chainId: partnerChainId(read.partner),
      });
    }
  }

  const gtd =
    manualGtd || holdings.some((holding) => holding.phase === "GTD");
  const fcfsFromNft = holdings.some((holding) => holding.phase === "FCFS");
  const fcfsViaGtd = gtd;

  return {
    ok: true,
    result: {
      address,
      chainId: ROBINHOOD_CHAIN_ID,
      gtd,
      fcfs: fcfsFromNft || fcfsViaGtd,
      public: true,
      manualGtd,
      fcfsViaGtd,
      holdings,
      failed,
    },
  };
}
