import { normalizeUri } from "@/lib/pet-image";
import { SITE } from "@/lib/site";

const COLLECTION_JSON = /^(https?:\/\/[^/]+)\/(?:egg-metadata|metadata)\/\d+\.json$/;

export function revealGifUrls(tokenUri: string, tokenId: string) {
  const url = normalizeUri(tokenUri);
  if (!url || url.startsWith("data:")) return null;
  const match = url.match(COLLECTION_JSON);
  if (!match) return null;
  const root = match[1];
  return {
    egg: `${root}/egg/${tokenId}.gif`,
    art: `${root}/art/${tokenId}.gif`,
  };
}

export function revealPostText(input: {
  tokenId: string;
  name: string | null;
  rewards?: string;
}) {
  const who = input.name
    ? `${input.name} #${input.tokenId}`
    : `Terminal Pet #${input.tokenId}`;
  const dial = input.rewards?.trim()
    ? ` Dial assigned ${input.rewards.trim()}.`
    : "";
  return `I ignited ${who} on ${SITE.chain}.${dial} The egg opened and the pet is awake. ${SITE.url}`;
}

export function revealFileName(tokenId: string) {
  return `terminal-pet-${tokenId}-reveal.gif`;
}
