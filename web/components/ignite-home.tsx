"use client";

import { ConnectButton } from "@/components/connect-button";
import { FaqList } from "@/components/faq-list";
import { NetworkHelp } from "@/components/network-help";
import { RevealPostButton } from "@/components/reveal-post-button";
import { TokenCard } from "@/components/token-card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import {
  friendlyChainError,
  technicalChainError,
} from "@/lib/chain-errors";
import { activeChain, configuredChainId, explorerUrl } from "@/lib/chain";
import {
  addresses,
  collectionAbi,
  contractsConfigured,
  erc20Abi,
  hopperAbi,
  igniteAbi,
  pulseAbi,
} from "@/lib/contracts";
import { asDial, dialRewardLabels, joinLabels, type DialView } from "@/lib/dial";
import { explorerTx, formatEthTrim, payoutLockCopy } from "@/lib/format";
import { FAQ, SITE } from "@/lib/site";
import Link from "next/link";
import { useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { parseEther, type Address } from "viem";
import {
  useAccount,
  useReadContract,
  useReadContracts,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

/** Confirmed on Robinhood Chain `IgniteModule.igniteFeeEth()` and CollectionConfig. Not a transaction fallback. */
const EXPECTED_IGNITE_FEE_ETH = parseEther("0.002");

const STEPS = [
  {
    n: "1",
    title: "Connect",
    body: "Use the wallet that holds your egg.",
  },
  {
    n: "2",
    title: "Ignite",
    body: `One button. ${SITE.igniteFeeEth}. The $TERM is already in the egg.`,
  },
  {
    n: "3",
    title: "Collect",
    body: "Awake pets earn from the Hopper after the lock.",
  },
] as const;

function hopperFill(available?: bigint, threshold?: bigint) {
  if (!available || !threshold || threshold === BigInt(0)) {
    return available && available > BigInt(0) ? 100 : 0;
  }
  const pct = Number((available * BigInt(10000)) / threshold) / 100;
  return Math.min(100, pct);
}

export function IgniteHome() {
  const configured = contractsConfigured();
  const { address, isConnected, chainId } = useAccount();
  const onTarget = chainId === configuredChainId();
  const chain = activeChain();
  const explorer = explorerUrl();
  const { writeContract, data: hash, isPending, error: writeError, reset } =
    useWriteContract();
  const { isLoading: waiting, isSuccess } = useWaitForTransactionReceipt({ hash });
  const [action, setAction] = useState<string | null>(null);
  const [awakenedId, setAwakenedId] = useState<bigint | null>(null);
  const actionRef = useRef<string | null>(null);

  const stats = useReadContracts({
    contracts: configured
      ? [
          {
            address: addresses.ignite,
            abi: igniteAbi,
            functionName: "litCount",
          },
          {
            address: addresses.ignite,
            abi: igniteAbi,
            functionName: "igniteFee",
          },
          {
            address: addresses.ignite,
            abi: igniteAbi,
            functionName: "igniteFeeEth",
          },
          {
            address: addresses.hopper,
            abi: hopperAbi,
            functionName: "available",
          },
          {
            address: addresses.pulse,
            abi: pulseAbi,
            functionName: "pulseThreshold",
          },
          {
            address: addresses.hopper,
            abi: hopperAbi,
            functionName: "hopperUnlocked",
          },
          {
            address: addresses.hopper,
            abi: hopperAbi,
            functionName: "hopperUnlockTime",
          },
          {
            address: addresses.ignite,
            abi: igniteAbi,
            functionName: "igniteEnabled",
          },
        ]
      : [],
    query: { enabled: configured, refetchInterval: 12_000 },
  });

  function readAt<T>(index: number): T | undefined {
    const row = stats.data?.[index];
    if (!row || row.status !== "success") return undefined;
    return row.result as T;
  }

  const litCount = readAt<bigint>(0);
  const igniteFeeTerm = readAt<bigint>(1);
  const igniteFeeEth = readAt<bigint>(2);
  const available = readAt<bigint>(3);
  const threshold = readAt<bigint>(4);
  const hopperUnlocked = readAt<boolean>(5);
  const hopperUnlockTime = readAt<bigint>(6);
  const igniteRow = stats.data?.[7];
  const igniteStatus =
    igniteRow?.status === "success"
      ? igniteRow.result
        ? "open"
        : "closed"
      : stats.isLoading
        ? "loading"
        : "unknown";

  const tokensQuery = useReadContract({
    address: addresses.collection,
    abi: collectionAbi,
    functionName: "tokensOfOwner",
    args: address ? [address] : undefined,
    query: { enabled: configured && Boolean(address) && onTarget },
  });
  const tokenIds = (tokensQuery.data as bigint[] | undefined) ?? [];

  const tokenReads = useReadContracts({
    contracts: tokenIds.flatMap((id) => [
      {
        address: addresses.ignite,
        abi: igniteAbi,
        functionName: "isLit" as const,
        args: [id] as const,
      },
      {
        address: addresses.pulse,
        abi: pulseAbi,
        functionName: "pending" as const,
        args: [id] as const,
      },
      {
        address: addresses.ignite,
        abi: igniteAbi,
        functionName: "allotmentConsumed" as const,
        args: [id] as const,
      },
    ]),
    query: { enabled: configured && tokenIds.length > 0 && onTarget },
  });

  function tokenField(index: number, field: 0 | 1 | 2) {
    return tokenReads.data?.[index * 3 + field]?.result;
  }

  const dialTargets = tokenIds.filter(
    (id, index) => Boolean(tokenField(index, 0)) || awakenedId === id,
  );
  const dialReads = useReadContracts({
    contracts: dialTargets.map((id) => ({
      address: addresses.pulse,
      abi: pulseAbi,
      functionName: "previewDial" as const,
      args: [id] as const,
    })),
    query: { enabled: configured && dialTargets.length > 0 && onTarget },
  });

  function dialFor(id: bigint): DialView | null {
    const index = dialTargets.findIndex((item) => item === id);
    if (index < 0) return null;
    return asDial(dialReads.data?.[index]?.result);
  }

  const refetchStats = stats.refetch;
  const refetchTokens = tokensQuery.refetch;
  const refetchTokenReads = tokenReads.refetch;
  const refetchDials = dialReads.refetch;

  useEffect(() => {
    if (!isSuccess || !hash) return;
    const label = actionRef.current;
    if (label?.startsWith("Ignite #")) {
      try {
        setAwakenedId(BigInt(label.slice("Ignite #".length)));
      } catch {
        setAwakenedId(null);
      }
    }
    setAction(null);
    void refetchStats();
    void refetchTokens();
    void refetchTokenReads();
    void refetchDials();
  }, [
    isSuccess,
    hash,
    refetchStats,
    refetchTokens,
    refetchTokenReads,
    refetchDials,
  ]);

  const busy = isPending || waiting;
  const feeLabel = igniteFeeEth !== undefined ? formatEthTrim(igniteFeeEth) : SITE.igniteFeeEth;
  const feeMismatch =
    igniteFeeEth !== undefined && igniteFeeEth !== EXPECTED_IGNITE_FEE_ETH;
  const payoutCopy = payoutLockCopy(hopperUnlocked, hopperUnlockTime);
  const awakeDial = awakenedId !== null ? dialFor(awakenedId) : null;
  const awakeRewards =
    awakeDial && awakeDial.nLegs > 0 ? joinLabels(dialRewardLabels(awakeDial)) : "";

  function run(label: string, fn: () => void) {
    reset();
    actionRef.current = label;
    setAction(label);
    fn();
  }

  const homeFaq = useMemo(() => FAQ.slice(0, 6), []);

  return (
    <div className="relative">
      <div className="hub-grid pointer-events-none absolute inset-0 opacity-60" />
      <main className="relative mx-auto flex max-w-6xl flex-col gap-10 px-4 py-10 sm:px-6">
        <section className="grid items-center gap-8 lg:grid-cols-[1.15fr_0.85fr]">
          <div className="space-y-4">
            <div className="flex flex-wrap items-center gap-2">
              <Badge variant="outline" className="font-mono">
                Minted out · {SITE.supply} pets · {chain.name}
              </Badge>
              <IgnitePill status={configured ? igniteStatus : "unknown"} />
            </div>
            <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
              Your eggs are ready. Wake them up.
            </h1>
            <p className="max-w-xl text-lg text-muted-foreground">
              Ignite turns a sleeping egg into a pet. It costs {feeLabel}. The
              $TERM is already in the egg.
            </p>
            {feeMismatch && (
              <p className="text-sm text-muted-foreground">
                The contract fee is {formatEthTrim(igniteFeeEth)}, so that is
                the amount your wallet will send.
              </p>
            )}
          </div>
          <figure className="mx-auto w-full max-w-sm">
            {/* Local example GIF. Kept as img so the animation is not re-encoded. */}
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src="/art/hatch/snag_hatch.gif"
              alt="Example of an egg cracking open and a pet waking up"
              width={512}
              height={512}
              className="aspect-square w-full rounded-2xl border border-border/70 bg-card object-contain"
            />
            <figcaption className="mt-2 text-center text-xs text-muted-foreground">
              Example wake-up. Your egg has its own art.
            </figcaption>
          </figure>
        </section>

        {!configured && (
          <Card className="border-destructive/40">
            <CardHeader>
              <CardTitle>Contracts aren&apos;t configured</CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              This build has no collection address, so eggs can&apos;t be listed.
            </CardContent>
          </Card>
        )}

        {configured && stats.isError && (
          <Card className="border-destructive/40">
            <CardHeader>
              <CardTitle>Couldn&apos;t read Robinhood Chain</CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-sm text-muted-foreground">
              <p>Check your connection, then try again. Your eggs are still safe.</p>
              <Button variant="outline" size="sm" onClick={() => void stats.refetch()}>
                Retry
              </Button>
            </CardContent>
          </Card>
        )}

        {!isConnected && (
          <section className="space-y-4">
            <ConnectButton prominent />
            <NetworkHelp connected={false} />
          </section>
        )}

        {isConnected && !onTarget && <NetworkHelp connected />}

        {isConnected && onTarget && (
          <section className="space-y-4" id="eggs">
            <div>
              <h2 className="text-2xl font-semibold tracking-tight">Your eggs</h2>
              <p className="text-sm text-muted-foreground">
                Press Ignite on a sleeping egg. You need {feeLabel} on{" "}
                {chain.name}, plus a little extra for gas.
              </p>
            </div>

            {igniteStatus === "closed" && (
              <Card className="border-primary/40">
                <CardContent className="py-4 text-sm text-muted-foreground">
                  Ignite isn&apos;t open yet. You can still see your eggs. Waking
                  them will work once it is switched on.
                </CardContent>
              </Card>
            )}

            {tokensQuery.isLoading && (
              <Empty title="Looking up your eggs…" body="Checking this wallet on Robinhood Chain." />
            )}
            {tokensQuery.isError && (
              <Empty
                title="Couldn't list your eggs"
                body="The collection didn't answer. Check the network, then retry."
              />
            )}
            {!tokensQuery.isLoading && !tokensQuery.isError && tokenIds.length === 0 && (
              <Empty
                title="No eggs in this wallet"
                body="The mint is over. If you bought a pet, connect the wallet that holds it."
              />
            )}

            {awakenedId !== null && isSuccess && (
              <Card className="border-primary/50">
                <CardHeader>
                  <CardTitle>Your pet is awake</CardTitle>
                </CardHeader>
                <CardContent className="space-y-2 text-sm text-muted-foreground">
                  <p>
                    #{awakenedId.toString()} is lit
                    {awakeRewards ? ` and Dial assigned ${awakeRewards}` : ""}.
                  </p>
                  <p>
                    Next: it earns from Pulse payouts out of the Hopper ETH pot.{" "}
                    {payoutCopy}
                  </p>
                  <RevealPostButton
                    tokenId={awakenedId}
                    rewards={awakeRewards}
                    prominent
                  />
                  <Button variant="outline" size="sm" asChild>
                    <Link href="/hopper">See Hopper & Pulse</Link>
                  </Button>
                </CardContent>
              </Card>
            )}

            {tokenIds.length > 0 && (
              <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
                {tokenIds.map((id, index) => (
                  <TokenCard
                    key={id.toString()}
                    tokenId={id}
                    lit={Boolean(tokenField(index, 0))}
                    pending={tokenField(index, 1) as bigint | undefined}
                    allotmentConsumed={Boolean(tokenField(index, 2))}
                    igniteFeeEth={igniteFeeEth}
                    igniteFeeTerm={igniteFeeTerm}
                    igniteStatus={igniteStatus}
                    owner={address}
                    busy={busy}
                    justAwoke={awakenedId === id && Boolean(isSuccess)}
                    dial={dialFor(id)}
                    hopperUnlocked={hopperUnlocked}
                    hopperUnlockTime={hopperUnlockTime}
                    refreshKey={hash}
                    onIgnite={() => {
                      if (igniteFeeEth === undefined) return;
                      run(`Ignite #${id}`, () =>
                        writeContract({
                          address: addresses.ignite,
                          abi: igniteAbi,
                          functionName: "ignite",
                          args: [id],
                          value: igniteFeeEth,
                        }),
                      );
                    }}
                    onApprove={() => {
                      if (igniteFeeTerm === undefined || !address) return;
                      run(`Approve #${id}`, () =>
                        writeContract({
                          address: addresses.term,
                          abi: erc20Abi,
                          functionName: "approve",
                          args: [addresses.ignite, igniteFeeTerm],
                        }),
                      );
                    }}
                    onClaim={() =>
                      run(`Collect #${id}`, () =>
                        writeContract({
                          address: addresses.pulse,
                          abi: pulseAbi,
                          functionName: "claim",
                          args: [id],
                        }),
                      )
                    }
                  />
                ))}
              </div>
            )}

            {(writeError || hash) && (
              <TxStatus
                action={action}
                error={writeError}
                hash={hash}
                explorer={explorer}
                waiting={waiting}
                success={isSuccess}
              />
            )}
          </section>
        )}

        <section className="grid gap-3 sm:grid-cols-3">
          {STEPS.map((step) => (
            <Card key={step.n}>
              <CardContent className="pt-5">
                <p className="font-mono text-[11px] tracking-[0.18em] text-primary">
                  {step.n}
                </p>
                <p className="mt-1 font-medium">{step.title}</p>
                <p className="mt-1 text-sm text-muted-foreground">{step.body}</p>
              </CardContent>
            </Card>
          ))}
        </section>

        <section className="grid gap-3 sm:grid-cols-3">
          <Stat
            label="Awake pets"
            value={litCount !== undefined ? litCount.toString() : stats.isLoading ? "…" : "—"}
            hint="Only awake pets earn payouts"
          />
          <Stat
            label="Hopper pot"
            value={formatEthTrim(available)}
            hint={payoutCopy}
          />
          <Stat
            label="Next payout needs"
            value={formatEthTrim(threshold)}
            hint={
              <span>
                In the pot before Pulse can run.{" "}
                <Link className="underline-offset-2 hover:underline" href="/hopper">
                  Hopper & Pulse
                </Link>
              </span>
            }
          />
        </section>

        <Card>
          <CardContent className="space-y-3 pt-5">
            <div className="flex items-end justify-between font-mono text-xs text-muted-foreground">
              <span>{formatEthTrim(available)} in the pot</span>
              <span>{formatEthTrim(threshold)} to the next payout</span>
            </div>
            <Progress value={hopperFill(available, threshold)} />
          </CardContent>
        </Card>

        <section className="space-y-3" id="faq">
          <div className="flex items-end justify-between gap-3">
            <h2 className="text-2xl font-semibold tracking-tight">Questions</h2>
            <Link
              href="/how#faq"
              className="text-sm text-muted-foreground underline-offset-2 hover:underline"
            >
              More answers
            </Link>
          </div>
          <FaqList items={homeFaq} />
        </section>
      </main>
    </div>
  );
}

function IgnitePill({
  status,
}: {
  status: "loading" | "open" | "closed" | "unknown";
}) {
  const label =
    status === "open"
      ? "Ignite is open"
      : status === "closed"
        ? "Ignite isn't open yet"
        : status === "loading"
          ? "Checking Ignite"
          : "Ignite status unknown";
  return <Badge variant={status === "open" ? "default" : "secondary"}>{label}</Badge>;
}

function Stat({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint: ReactNode;
}) {
  return (
    <Card>
      <CardContent className="pt-5">
        <p className="font-mono text-[11px] tracking-[0.18em] text-muted-foreground">
          {label}
        </p>
        <p className="mt-1 font-mono text-2xl text-foreground">{value}</p>
        <p className="mt-1 text-xs text-muted-foreground">{hint}</p>
      </CardContent>
    </Card>
  );
}

function Empty({ title, body }: { title: string; body: string }) {
  return (
    <Card className="border-dashed">
      <CardContent className="py-10 text-center">
        <p className="font-medium">{title}</p>
        <p className="mx-auto mt-2 max-w-md text-sm text-muted-foreground">{body}</p>
      </CardContent>
    </Card>
  );
}

function TxStatus({
  action,
  error,
  hash,
  explorer,
  waiting,
  success,
}: {
  action: string | null;
  error: unknown;
  hash?: Address;
  explorer: string;
  waiting: boolean;
  success: boolean;
}) {
  const technical = error ? technicalChainError(error) : "";
  const friendly = error ? friendlyChainError(error) : "";
  return (
    <Card>
      <CardContent className="space-y-2 pt-6 text-sm">
        {action && <p className="font-mono text-xs text-muted-foreground">{action}</p>}
        {error ? (
          <div className="space-y-2">
            <p className="text-destructive">{friendly}</p>
            {technical && technical !== friendly ? (
              <details className="text-xs text-muted-foreground">
                <summary className="cursor-pointer">Technical details</summary>
                <p className="mt-1 font-mono">{technical}</p>
              </details>
            ) : null}
          </div>
        ) : null}
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
            {waiting ? " · confirming" : success ? " · confirmed" : ""}
          </p>
        )}
      </CardContent>
    </Card>
  );
}
