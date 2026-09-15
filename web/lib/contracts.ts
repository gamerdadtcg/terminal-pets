import { type Address, parseAbi, zeroAddress } from "viem";

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
  "function royaltyReceiver() view returns (address)",
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

function addr(value: string | undefined): Address {
  if (!value) return zeroAddress;
  return value as Address;
}

export const addresses = {
  collection: addr(process.env.NEXT_PUBLIC_COLLECTION_ADDRESS),
  ignite: addr(process.env.NEXT_PUBLIC_IGNITE_ADDRESS),
  hopper: addr(process.env.NEXT_PUBLIC_HOPPER_ADDRESS),
  pulse: addr(process.env.NEXT_PUBLIC_PULSE_ADDRESS),
  splitter: addr(process.env.NEXT_PUBLIC_SPLITTER_ADDRESS),
  term: addr(process.env.NEXT_PUBLIC_TERM_ADDRESS),
  termFund: addr(process.env.NEXT_PUBLIC_TERM_FUND_ADDRESS),
  termMarket: addr(process.env.NEXT_PUBLIC_TERM_MARKET_ADDRESS),
};

export function contractsConfigured() {
  return (
    addresses.collection !== zeroAddress &&
    addresses.ignite !== zeroAddress &&
    addresses.hopper !== zeroAddress &&
    addresses.pulse !== zeroAddress
  );
}
