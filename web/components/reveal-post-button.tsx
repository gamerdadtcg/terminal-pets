"use client";

import { Button } from "@/components/ui/button";
import { addresses, collectionAbi, zeroAddress } from "@/lib/contracts";
import { resolvePetMeta } from "@/lib/pet-image";
import {
  revealFileName,
  revealGifUrls,
  revealPost,
} from "@/lib/reveal-post";
import { useState } from "react";
import { useReadContract } from "wagmi";

function downloadGif(bytes: Uint8Array, filename: string) {
  const copy = new Uint8Array(bytes);
  const url = URL.createObjectURL(new Blob([copy], { type: "image/gif" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = filename;
  link.click();
  URL.revokeObjectURL(url);
}

export function RevealPostButton({
  tokenId,
  rewards,
  prominent,
}: {
  tokenId: bigint;
  rewards?: string;
  prominent?: boolean;
}) {
  const id = tokenId.toString();
  const { data: tokenUri } = useReadContract({
    address: addresses.collection,
    abi: collectionAbi,
    functionName: "tokenURI",
    args: [tokenId],
    query: { enabled: addresses.collection !== zeroAddress },
  });
  const [working, setWorking] = useState(false);
  const [note, setNote] = useState<string | null>(null);
  const [caption, setCaption] = useState<string | null>(null);

  async function save() {
    if (!tokenUri || working) return;
    setWorking(true);
    setNote(null);
    setCaption(null);
    try {
      const urls = revealGifUrls(tokenUri, id);
      if (!urls) throw new Error("missing art");
      const [meta, eggRes, artRes] = await Promise.all([
        resolvePetMeta(tokenUri),
        fetch(urls.egg),
        fetch(urls.art),
      ]);
      if (!eggRes.ok || !artRes.ok) throw new Error("art fetch");
      const [egg, art] = await Promise.all([
        eggRes.arrayBuffer(),
        artRes.arrayBuffer(),
      ]);
      const { composeRevealGif } = await import("@/lib/reveal-gif");
      const post = revealPost({ tokenId: id, name: meta.title, rewards });
      const gif = await composeRevealGif(egg, art, {
        title: post.title,
        subtitle: post.subtitle,
      });
      downloadGif(gif, revealFileName(id));
      let copied = false;
      try {
        await navigator.clipboard.writeText(post.text);
        copied = true;
      } catch {
        copied = false;
      }
      setCaption(copied ? null : post.text);
      setNote(
        copied
          ? "Saved the GIF. The caption is copied — paste it with the GIF."
          : "Saved the GIF. Copy this caption and paste it with the file:",
      );
    } catch {
      setNote("Couldn't build that reveal GIF. Try again in a moment.");
    } finally {
      setWorking(false);
    }
  }

  return (
    <div className="space-y-2">
      <Button
        className="h-11 w-full"
        variant={prominent ? "default" : "outline"}
        onClick={() => void save()}
        disabled={working || !tokenUri}
      >
        {working ? "Building your GIF…" : "Save reveal post"}
      </Button>
      <p className="text-xs text-muted-foreground">
        Saves a GIF of your egg opening into your pet, and copies “I just woke up…”.
      </p>
      {note && <p className="text-xs text-muted-foreground">{note}</p>}
      {caption && (
        <p className="break-words rounded-md border border-border/70 bg-background/40 p-2 font-mono text-xs text-foreground">
          {caption}
        </p>
      )}
    </div>
  );
}
