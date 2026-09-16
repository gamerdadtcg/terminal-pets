"use client";

import { ConnectButton } from "@/components/connect-button";
import { MintScheduleCard } from "@/components/hub/mint-schedule";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { activeChain, configuredChainId, explorerUrl } from "@/lib/chain";
import {
  addresses,
  collectionAbi,
  collectionConfigured,
  zeroAddress,
} from "@/lib/contracts";
import { explorerAddress, explorerTx, formatEth, shortAddress } from "@/lib/format";
import { SITE, mintAllocation, mintScheduleCopy } from "@/lib/site";
import { useEffect, useMemo, useState } from "react";
import { isAddress, type Address } from "viem";
import {
  useAccount,
  useReadContracts,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";
import Link from "next/link";

export function MintPanel() {
  const configured = collectionConfigured();
  const { address, isConnected, chainId } = useAccount();
  const onTarget = chainId === configuredChainId();
  const chain = activeChain();
  const explorer = explorerUrl();
  const [mintTo, setMintTo] = useState("");

  const { writeContract, data: hash, isPending, error: writeError, reset } =
    useWriteContract();
  const { isLoading: waiting, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const reads = useReadContracts({
    contracts: configured
      ? [
          {
            address: addresses.collection,
            abi: collectionAbi,
            functionName: "mintOpen" as const,
          },
          {
            address: addresses.collection,
            abi: collectionAbi,
            functionName: "mintPrice" as const,
          },
          {
            address: addresses.collection,
            abi: collectionAbi,
            functionName: "publicMinted" as const,
          },
          {
            address: addresses.collection,
            abi: collectionAbi,
            functionName: "publicSupply" as const,
          },
          {
            address: addresses.collection,
            abi: collectionAbi,
            functionName: "totalSupply" as const,
          },
          {
            address: addresses.collection,
            abi: collectionAbi,
            functionName: "maxSupply" as const,
          },
          {
            address: addresses.collection,
            abi: collectionAbi,
            functionName: "numberMinted" as const,
            args: [address ?? zeroAddress],
          },
        ]
      : [],
    query: { enabled: configured, refetchInterval: 12_000 },
  });

  const refetchMint = reads.refetch;

  useEffect(() => {
    if (!isSuccess) return;
    void refetchMint();
  }, [isSuccess, refetchMint]);

  const mintOpen = reads.data?.[0]?.result as boolean | undefined;
  const mintPrice = reads.data?.[1]?.result as bigint | undefined;
  const publicMinted = reads.data?.[2]?.result as bigint | undefined;
  const publicSupply = reads.data?.[3]?.result as bigint | undefined;
  const totalSupply = reads.data?.[4]?.result as bigint | undefined;
  const maxSupply = reads.data?.[5]?.result as bigint | undefined;
  const numberMinted = reads.data?.[6]?.result as bigint | undefined;

  const remaining =
    publicMinted !== undefined && publicSupply !== undefined
      ? publicSupply - publicMinted
      : undefined;
  const soldOut = remaining !== undefined && remaining <= BigInt(0);
  const busy = isPending || waiting;
  const recipient = mintTo.trim();
  const recipientOk = recipient.length === 0 || isAddress(recipient);
  const usingMintTo = recipient.length > 0 && isAddress(recipient);

  const status = useMemo(() => {
    if (!configured) return "unconfigured" as const;
    if (reads.isError) return "error" as const;
    if (mintOpen === undefined) return "loading" as const;
    if (soldOut) return "soldout" as const;
    if (!mintOpen) return "closed" as const;
    return "open" as const;
  }, [configured, mintOpen, reads.isError, soldOut]);

  function mint() {
    reset();
    const to = usingMintTo ? (recipient as Address) : undefined;
    if (to) {
      writeContract({
        address: addresses.collection,
        abi: collectionAbi,
        functionName: "mintTo",
        args: [to, BigInt(1)],
        value: mintPrice ?? BigInt(0),
      });
      return;
    }
    writeContract({
      address: addresses.collection,
      abi: collectionAbi,
      functionName: "mint",
      args: [BigInt(1)],
      value: mintPrice ?? BigInt(0),
    });
  }

  const canMint =
    configured &&
    status === "open" &&
    isConnected &&
    onTarget &&
    recipientOk &&
    !busy;

  return (
    <div className="relative">
      <div className="hub-grid pointer-events-none absolute inset-0 opacity-70" />
      <div className="relative mx-auto grid max-w-6xl gap-8 px-4 py-12 sm:px-6 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="space-y-6">
          <div className="flex flex-wrap items-center gap-2">
            <Badge variant="outline" className="font-mono">
              {chain.name} · {configuredChainId()}
            </Badge>
            <Badge variant="outline" className="font-mono">
              {mintScheduleCopy.headline}
            </Badge>
            <MintStatusBadge status={status} />
          </div>
          <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
            Mint on this hub
          </h1>
          <p className="max-w-xl text-lg text-muted-foreground">
            Free mint. 1 Terminal Pet per transaction when on-chain{" "}
            <span className="font-mono text-foreground">mintOpen</span> is
            true. OpenSea Studio Drop create currently cannot import this
            contract and does not list Base Sepolia — do not mint through the
            Studio wizard.
          </p>
          <p className="max-w-xl text-sm text-muted-foreground">
            {mintScheduleCopy.sentence} {mintAllocation.sentence} After mint
            the pet is Sealed. Ignite is {SITE.igniteFeeEth} (plus the $TERM
            allotment) after reveal. Hopper claims lock {SITE.hopperLock}. Dial
            assigns 1–4 Stock Tokens by shell class at Ignite.
          </p>

          <Card
            className={
              status === "open"
                ? "border-primary/40"
                : status === "closed" || status === "soldout"
                  ? "border-destructive/40"
                  : "border-border/70"
            }
          >
            <CardHeader className="gap-2">
              <p className="font-mono text-[11px] text-primary">MINT STATUS</p>
              <CardTitle className="text-xl">
                {status === "open"
                  ? "Mint is open"
                  : status === "closed"
                    ? "Mint is closed"
                    : status === "soldout"
                      ? "Public supply minted"
                      : status === "unconfigured"
                        ? "Collection not configured"
                        : status === "error"
                          ? "Could not read mintOpen"
                          : "Reading mintOpen…"}
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4 text-sm text-muted-foreground">
              {status === "closed" && (
                <p>
                  CollectionNFT.mint / mintTo revert while{" "}
                  <span className="font-mono text-foreground">mintOpen</span>{" "}
                  is false. Connect on {chain.name}, then mint here when the
                  owner opens the hub path. Schedule times below are the public
                  windows — they are not separate on-chain phase contracts.
                </p>
              )}
              {status === "open" && (
                <p>
                  On-chain mint is open. This button calls{" "}
                  <span className="font-mono text-foreground">
                    CollectionNFT.{usingMintTo ? "mintTo" : "mint"}
                  </span>{" "}
                  for 1 token
                  {mintPrice && mintPrice > BigInt(0)
                    ? ` at ${formatEth(mintPrice)}`
                    : " (free)"}.
                </p>
              )}
              {status === "unconfigured" && (
                <p>
                  Set <span className="font-mono">NEXT_PUBLIC_CHAIN_ID</span>{" "}
                  and{" "}
                  <span className="font-mono">NEXT_PUBLIC_COLLECTION_NFT</span>{" "}
                  (Robinhood mainnet 4663 after deploy, or Base Sepolia 84532
                  for the dry-run). No mainnet broadcast from this hub PR.
                </p>
              )}
              {status === "error" && (
                <p>
                  Check the RPC, contract address, and that you are on{" "}
                  {chain.name}.
                </p>
              )}
              {status === "soldout" && (
                <p>
                  Public cap ({SITE.publicSupply}) is filled. Team reserve is
                  separate.
                </p>
              )}

              <div className="grid gap-2 font-mono text-xs text-foreground sm:grid-cols-2">
                <p>
                  Public minted{" "}
                  {publicMinted !== undefined && publicSupply !== undefined
                    ? `${publicMinted.toString()} / ${publicSupply.toString()}`
                    : configured
                      ? "…"
                      : "—"}
                </p>
                <p>
                  Total{" "}
                  {totalSupply !== undefined && maxSupply !== undefined
                    ? `${totalSupply.toString()} / ${maxSupply.toString()}`
                    : configured
                      ? "…"
                      : `0 / ${SITE.supply}`}
                </p>
                {isConnected && onTarget && numberMinted !== undefined && (
                  <p>Your wallet minted {numberMinted.toString()}</p>
                )}
                {configured && (
                  <p>
                    Collection {shortAddress(addresses.collection)}
                  </p>
                )}
              </div>

              <div className="flex flex-wrap items-center gap-2">
                <ConnectButton />
                {isConnected && onTarget && (
                  <Button onClick={mint} disabled={!canMint}>
                    {busy
                      ? waiting
                        ? "Confirming…"
                        : "Minting…"
                      : usingMintTo
                        ? "Mint 1 to address"
                        : "Mint 1"}
                  </Button>
                )}
              </div>

              {isConnected && onTarget && status === "open" && (
                <label className="block space-y-1.5">
                  <span className="font-mono text-[11px] tracking-wide text-muted-foreground">
                    Optional mintTo
                  </span>
                  <input
                    value={mintTo}
                    onChange={(event) => setMintTo(event.target.value)}
                    placeholder="0x… leave blank to mint to this wallet"
                    spellCheck={false}
                    className="h-9 w-full rounded-lg border border-border bg-background px-3 font-mono text-xs text-foreground outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
                  />
                  {!recipientOk && (
                    <span className="text-destructive">
                      Enter a valid 0x address or leave blank.
                    </span>
                  )}
                </label>
              )}

              {isConnected && !onTarget && (
                <p>
                  Wrong network. Switch to {chain.name} (chain id{" "}
                  {configuredChainId()}) to mint.
                </p>
              )}
              {!isConnected && status !== "unconfigured" && (
                <p>Connect a wallet on {chain.name} to mint.</p>
              )}

              {(writeError || hash) && (
                <div className="space-y-1 text-sm">
                  {writeError && (
                    <p className="text-destructive">
                      {"shortMessage" in writeError
                        ? String(writeError.shortMessage)
                        : writeError.message}
                    </p>
                  )}
                  {hash && (
                    <p>
                      Transaction{" "}
                      <a
                        className="underline-offset-2 hover:underline"
                        href={explorerTx(explorer, hash)}
                        target="_blank"
                        rel="noreferrer"
                      >
                        {hash.slice(0, 10)}…
                      </a>
                      {waiting
                        ? " · confirming"
                        : isSuccess
                          ? " · confirmed"
                          : ""}
                    </p>
                  )}
                </div>
              )}
            </CardContent>
          </Card>

          <div className="flex flex-wrap gap-2">
            <Button variant="outline" asChild>
              <Link href="/app">Ignite / Pulse after mint</Link>
            </Button>
            {configured && (
              <Button variant="ghost" asChild>
                <a
                  href={explorerAddress(explorer, addresses.collection)}
                  rel="noreferrer"
                  target="_blank"
                >
                  Collection on explorer
                </a>
              </Button>
            )}
          </div>
        </div>

        <div className="grid gap-3">
          <MintScheduleCard />
          <Card>
            <CardHeader>
              <p className="font-mono text-[11px] text-primary">AFTER MINT</p>
              <CardTitle className="text-base">
                Production economics
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 text-sm text-muted-foreground">
              <p>Ignite {SITE.igniteFeeEth} · {SITE.igniteEthSplit}.</p>
              <p>Hopper payouts lock {SITE.hopperLock} after reveal.</p>
              <p>Dial assigns 1–4 Stock Tokens by shell class at Ignite.</p>
              <p>
                Pets mint Sealed for {SITE.revealWindow}. Do not use Studio’s
                deploy-Drop wizard.
              </p>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}

function MintStatusBadge({
  status,
}: {
  status: "unconfigured" | "error" | "loading" | "soldout" | "closed" | "open";
}) {
  const label =
    status === "open"
      ? "mintOpen true"
      : status === "closed"
        ? "mintOpen false"
        : status === "soldout"
          ? "Sold out"
          : status === "unconfigured"
            ? "Set collection env"
            : status === "error"
              ? "Read failed"
              : "Reading…";
  return (
    <Badge variant="outline" className="font-mono">
      {label}
    </Badge>
  );
}
