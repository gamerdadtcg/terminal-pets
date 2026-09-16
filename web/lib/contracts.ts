import { type Address, parseAbi, zeroAddress } from "viem";
import { configuredChainId } from "@/lib/chain";
import { BASE_SEPOLIA_DRYRUN } from "@/lib/deployments";

export { zeroAddress };

export const collectionAbi = parseAbi([
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function maxSupply() view returns (uint256)",
  "function teamReserve() view returns (uint256)",
  "function publicSupply() view returns (uint256)",
  "function teamMinted() view returns (uint256)",
  "function publicMinted() view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function revealed() view returns (bool)",
  "function mintPrice() view returns (uint256)",
  "function mintOpen() view returns (bool)",
  "function hopper() view returns (address)",
  "function igniteModule() view returns (address)",
  "function royaltyReceiver() view returns (address)",
  "function numberMinted(address minter) view returns (uint256)",
  "function mint(uint256 quantity) payable returns (uint256)",
  "function mintTo(address to, uint256 quantity) payable returns (uint256)",
  "function tokensOfOwner(address owner) view returns (uint256[])",
  "function isLit(uint256 tokenId) view returns (bool)",
  "function ownerOf(uint256 tokenId) view returns (address)",
  "function royaltyInfo(uint256 tokenId, uint256 salePrice) view returns (address, uint256)",
]);

export const igniteAbi = parseAbi([
  "function ignite(uint256 tokenId) payable",
  "function isLit(uint256 tokenId) view returns (bool)",
  "function litCount() view returns (uint256)",
  "function igniteFee() view returns (uint256)",
  "function igniteFeeEth() view returns (uint256)",
  "function term() view returns (address)",
  "function termFund() view returns (address)",
  "function allotmentConsumed(uint256 tokenId) view returns (bool)",
  "function claimIgniteAllotment(uint256 tokenId)",
  "function allotmentBalance() view returns (uint256)",
]);

export const hopperAbi = parseAbi([
  "function available() view returns (uint256)",
  "function reserved() view returns (uint256)",
  "function distributor() view returns (address)",
  "function distributorLocked() view returns (bool)",
  "function hopperUnlocked() view returns (bool)",
  "function hopperUnlockTime() view returns (uint256)",
  "function revealedAt() view returns (uint64)",
]);

export const pulseAbi = parseAbi([
  "function pulse()",
  "function claim(uint256 tokenId)",
  "function claimMany(uint256[] tokenIds)",
  "function pending(uint256 tokenId) view returns (uint256)",
  "function canPulse() view returns (bool)",
  "function pulseThreshold() view returns (uint256)",
  "function bootstrapComplete() view returns (bool)",
  "function ladderIndex() view returns (uint8)",
  "function epochCount() view returns (uint256)",
  "function deliverToTba() view returns (bool)",
  "function tbaAddress(uint256 tokenId) view returns (address)",
]);

function envAddr(...keys: string[]): Address {
  for (const key of keys) {
    const value = process.env[key]?.trim();
    if (value) return value as Address;
  }
  return zeroAddress;
}

function withFallback(value: Address, fallback?: Address): Address {
  return value !== zeroAddress ? value : (fallback ?? zeroAddress);
}

function sepoliaFallback() {
  return configuredChainId() === BASE_SEPOLIA_DRYRUN.chainId
    ? BASE_SEPOLIA_DRYRUN
    : undefined;
}

const dryrun = sepoliaFallback();

export const addresses = {
  collection: withFallback(
    envAddr("NEXT_PUBLIC_COLLECTION_NFT", "NEXT_PUBLIC_COLLECTION_ADDRESS"),
    dryrun?.collection,
  ),
  ignite: withFallback(envAddr("NEXT_PUBLIC_IGNITE_ADDRESS"), dryrun?.ignite),
  hopper: withFallback(envAddr("NEXT_PUBLIC_HOPPER_ADDRESS"), dryrun?.hopper),
  pulse: withFallback(envAddr("NEXT_PUBLIC_PULSE_ADDRESS"), dryrun?.pulse),
  splitter: withFallback(
    envAddr("NEXT_PUBLIC_SPLITTER_ADDRESS"),
    dryrun?.splitter,
  ),
  term: withFallback(envAddr("NEXT_PUBLIC_TERM_ADDRESS"), dryrun?.term),
  termFund: withFallback(
    envAddr("NEXT_PUBLIC_TERM_FUND_ADDRESS"),
    dryrun?.termFund,
  ),
  termMarket: withFallback(
    envAddr("NEXT_PUBLIC_TERM_MARKET_ADDRESS"),
    dryrun?.termMarket,
  ),
};

export function collectionConfigured() {
  return addresses.collection !== zeroAddress;
}

export function contractsConfigured() {
  return (
    collectionConfigured() &&
    addresses.ignite !== zeroAddress &&
    addresses.hopper !== zeroAddress &&
    addresses.pulse !== zeroAddress
  );
}
