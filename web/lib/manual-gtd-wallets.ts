import { getAddress, type Address } from "viem";

/**
 * Manual GTD wallets from the Terminal Pets X thread.
 *
 * Hub eligibility preview only. These addresses are **not** on-chain mint
 * allowlisted — CollectionNFT still gates mint on `mintOpen`. GTD-eligible
 * wallets also unlock FCFS on the hub preview. Travis still has to lock mint
 * phase before it is mint-live.
 *
 * To append wallets later:
 * 1. Add a 0x address to `MANUAL_GTD_WALLET_ADDRESSES` (any casing).
 * 2. Redeploy the hub. Lookup is case-insensitive (lowercase compare).
 *
 * Source: https://x.com/Terminal_Pets/status/2100393131308941528
 */
export const MANUAL_GTD_THREAD_URL =
  "https://x.com/Terminal_Pets/status/2100393131308941528";

/** UI / API reason shown when GTD is yes via this list (not an NFT collection). */
export const MANUAL_GTD_REASON = "GTD thread wallet";

/** Seed / append list — mixed-case 0x addresses are fine. */
const MANUAL_GTD_WALLET_ADDRESSES = [
  "0xe043e070d314e76da9cfb1ab4b068cf9ad2b14c6",
  "0x28a13d179c0b2e2fcd1a1210bdec1700032fbffa",
  "0x8f5b388c517b0e436e85a53953bdcda9820a89ea",
  "0xc59523e69dc4ef360702fe9cab9ac7376b5a4cb2",
  "0xaee065b741a85ca80260315c3409548d46683244",
  "0x1fb9a1f2b917b68e1a058593f48a44f3fa5cd2ab",
] as const;

function checksum(address: string): Address {
  return getAddress(address.toLowerCase());
}

/** EIP-55 checksummed addresses. */
export const MANUAL_GTD_WALLETS: readonly Address[] =
  MANUAL_GTD_WALLET_ADDRESSES.map(checksum);

/** Lowercase set for case-insensitive membership checks. */
export const MANUAL_GTD_WALLET_SET: ReadonlySet<string> = new Set(
  MANUAL_GTD_WALLETS.map((address) => address.toLowerCase()),
);

export function isManualGtdWallet(address: string): boolean {
  try {
    return MANUAL_GTD_WALLET_SET.has(checksum(address.trim()).toLowerCase());
  } catch {
    return false;
  }
}
