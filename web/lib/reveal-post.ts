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

export function revealPost(input: {
  tokenId: string;
  name: string | null;
  rewards?: string;
}) {
  const who = input.name
    ? `${input.name} #${input.tokenId}`
    : `Terminal Pet #${input.tokenId}`;
  const dial = input.rewards?.trim()
    ? ` Dial gave me ${input.rewards.trim()}.`
    : "";
  return {
    title: "I just woke up",
    subtitle: who,
    text: `I just woke up. I'm ${who} on ${SITE.chain}.${dial} ${SITE.url}`,
  };
}

export function revealFileName(tokenId: string) {
  return `terminal-pet-${tokenId}-reveal.gif`;
}
