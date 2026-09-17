import { getAddress, parseAbi, type Address } from "viem";
import { ETHEREUM_CHAIN_ID, ROBINHOOD_CHAIN_ID } from "@/lib/chain";

/**
 * Partner NFT collections that count toward GTD / FCFS phase eligibility.
 *
 * This is a live on-chain holdings check (ERC-721 `balanceOf`), not a Merkle
 * root or static address list. CollectionNFT still gates mint on `mintOpen`
 * only — these lists match the announced partner projects for Friday phases.
 *
 * To add a collection later:
 * 1. Append a `{ name, address }` row to `GTD_PARTNERS` or `FCFS_PARTNERS`.
 * 2. Use the Robinhood Chain (4663) contract address, unless this is a
 *    documented cross-chain exception (pass `chainId`, e.g. 1 for Ethereum).
 * 3. Redeploy the hub. No UI code changes needed.
 *
 * Manual GTD thread wallets live in `web/lib/manual-gtd-wallets.ts`.
 * GTD-eligible wallets (partner NFT or thread list) also unlock FCFS on the
 * hub preview. CollectionNFT still gates mint on `mintOpen` only.
 */
export type PartnerPhase = "GTD" | "FCFS";

export type PartnerCollection = {
  name: string;
  address: Address;
  phase: PartnerPhase;
  /** Defaults to Robinhood Chain (4663). Set `1` for Ethereum mainnet holdings. */
  chainId?: number;
};

function partner(
  name: string,
  address: string,
  phase: PartnerPhase,
  chainId: number = ROBINHOOD_CHAIN_ID,
): PartnerCollection {
  return {
    name,
    address: getAddress(address.toLowerCase()),
    phase,
    chainId,
  };
}

/** Eligible for GTD if `balanceOf` > 0 on ANY of these. */
export const GTD_PARTNERS: PartnerCollection[] = [
  partner("StonkBrokers", "0x539CdD042c2f3d93EbC5BE7DfFf0c79F3B4fAbF0", "GTD"),
  partner("QUOTRONS", "0x027ACa2794E44f24950D81227DcD516FfBB49d6e", "GTD"),
  partner("Chain Mancers", "0x797a2e030B7e49107C8F07bF0300Ea9caE88cA57", "GTD"),
  partner("Hashcats", "0xCA75DF55Cc9C476DB27a7375D1fc8E794cf80721", "GTD"),
  partner("WIF Outlaws", "0x12a4c7659a4b7c4a2870b5167c4f8b014c7fa690", "GTD"),
  // Genesis collection on Ethereum mainnet. Same wallet addresses on RH.
  partner(
    "School of NFTs",
    "0xfc46d61fee808dbaf30e164b6bdeadc26155257e",
    "GTD",
    ETHEREUM_CHAIN_ID,
  ),
];

/**
 * Eligible for FCFS if `balanceOf` > 0 on ANY of these (Robinhood Chain),
 * or if the wallet is GTD-eligible (partner NFT or manual thread list).
 */
export const FCFS_PARTNERS: PartnerCollection[] = [
  partner("RH MACHINES", "0x8c71d170fbd94bcba93bb08fc2cfd0e8620cd9ce", "FCFS"),
  partner("Opencatz AI", "0xf0474980e09c3023655a9ca3e71a763358214efb", "FCFS"),
  partner("Rekt Tradooors", "0x7b3ecfa33657de415ff269dc97dfa82954cee706", "FCFS"),
  partner("Builder Bots AI", "0x409eab4fa20b5b61d35d2b447b14f384e8ac90e5", "FCFS"),
  partner("GoatStreetCashmere", "0xc21159f412c294ca2c38f2a9ecaaccf9d93ec929", "FCFS"),
];

export const ALL_PARTNERS: PartnerCollection[] = [
  ...GTD_PARTNERS,
  ...FCFS_PARTNERS,
];

export const ERC721_BALANCE_ABI = parseAbi([
  "function balanceOf(address owner) view returns (uint256)",
]);
