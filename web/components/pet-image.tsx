"use client";

import { addresses, collectionAbi, zeroAddress } from "@/lib/contracts";
import { resolvePetMeta } from "@/lib/pet-image";
import { useEffect, useState } from "react";
import { useReadContract } from "wagmi";

export function PetImage({
  tokenId,
  refreshKey,
}: {
  tokenId: bigint;
  refreshKey?: string;
}) {
  const { data, refetch } = useReadContract({
    address: addresses.collection,
    abi: collectionAbi,
    functionName: "tokenURI",
    args: [tokenId],
    query: { enabled: addresses.collection !== zeroAddress },
  });
  const [image, setImage] = useState<string | null>(null);
  const [title, setTitle] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (!refreshKey) return;
    void refetch();
  }, [refreshKey, refetch]);

  useEffect(() => {
    if (!data) return;
    let cancel = false;
    void resolvePetMeta(data).then((meta) => {
      if (cancel) return;
      setFailed(false);
      setImage(meta.image);
      setTitle(meta.title);
    });
    return () => {
      cancel = true;
    };
  }, [data]);

  const src = !failed && image ? image : "/art/sealed.gif";
  const alt = title ? `${title} · #${tokenId.toString()}` : `Pet #${tokenId.toString()}`;

  return (
    // Collection art is a remote GIF chosen per token. next/image would need every host.
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src={src}
      alt={alt}
      width={512}
      height={512}
      onError={() => setFailed(true)}
      className="aspect-square w-full rounded-xl border border-border/70 bg-background object-contain"
    />
  );
}
