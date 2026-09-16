"use client";

import { ComingSoon } from "@/components/coming-soon";
import { TokenCard } from "@/components/token-card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Separator } from "@/components/ui/separator";
import { activeChain, configuredChainId, explorerUrl } from "@/lib/chain";
import {
  addresses,
  collectionAbi,
  contractsConfigured,
  hopperAbi,
  igniteAbi,
  pulseAbi,
  zeroAddress,
} from "@/lib/contracts";
import { explorerAddress, explorerTx, formatEth } from "@/lib/format";
import { SITE, mintAllocation, mintScheduleCopy } from "@/lib/site";
import { useMemo, useState } from "react";
import Link from "next/link";
import {
  useAccount,
  useReadContract,
  useReadContracts,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

function hopperFill(available?: bigint, threshold?: bigint) {
  if (!available || !threshold || threshold === BigInt(0)) {
    return available && available > BigInt(0) ? 100 : 0;
  }
  const pct = Number((available * BigInt(10000)) / threshold) / 100;
  return Math.min(100, pct);
}

export function TerminalApp() {
  const configured = contractsConfigured();
  const { address, isConnected, chainId } = useAccount();
  const onTarget = chainId === configuredChainId();
  const explorer = explorerUrl();
  const chain = activeChain();

  const { writeContract, data: hash, isPending, error: writeError, reset } =
    useWriteContract();
  const { isLoading: waiting, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });
  const [action, setAction] = useState<string | null>(null);

  const statsContracts = useMemo(
    () =>
      configured
        ? [
            {
              address: addresses.collection,
              abi: collectionAbi,
              functionName: "name" as const,
            },
            {
              address: addresses.collection,
              abi: collectionAbi,
              functionName: "symbol" as const,
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
              functionName: "mintOpen" as const,
            },
            {
              address: addresses.collection,
              abi: collectionAbi,
              functionName: "mintPrice" as const,
            },
            {
              address: addresses.ignite,
              abi: igniteAbi,
              functionName: "litCount" as const,
            },
            {
              address: addresses.ignite,
              abi: igniteAbi,
              functionName: "igniteFee" as const,
            },
            {
              address: addresses.hopper,
              abi: hopperAbi,
              functionName: "available" as const,
            },
            {
              address: addresses.hopper,
              abi: hopperAbi,
              functionName: "reserved" as const,
            },
            {
              address: addresses.pulse,
              abi: pulseAbi,
              functionName: "pulseThreshold" as const,
            },
            {
              address: addresses.pulse,
              abi: pulseAbi,
              functionName: "canPulse" as const,
            },
            {
              address: addresses.pulse,
              abi: pulseAbi,
              functionName: "epochCount" as const,
            },
            {
              address: addresses.pulse,
              abi: pulseAbi,
              functionName: "deliverToTba" as const,
            },
            {
              address: addresses.pulse,
              abi: pulseAbi,
              functionName: "bootstrapComplete" as const,
            },
            {
              address: addresses.pulse,
              abi: pulseAbi,
              functionName: "ladderIndex" as const,
            },
            {
              address: addresses.ignite,
              abi: igniteAbi,
              functionName: "igniteFeeEth" as const,
            },
            {
              address: addresses.hopper,
              abi: hopperAbi,
              functionName: "hopperUnlocked" as const,
            },
            {
              address: addresses.hopper,
              abi: hopperAbi,
              functionName: "hopperUnlockTime" as const,
            },
          ]
        : [],
    [configured],
  );

  const stats = useReadContracts({
    contracts: statsContracts,
    query: { enabled: configured, refetchInterval: 12_000 },
  });

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
        address: addresses.pulse,
        abi: pulseAbi,
        functionName: "tbaAddress" as const,
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

  const name = stats.data?.[0]?.result as string | undefined;
  const symbol = stats.data?.[1]?.result as string | undefined;
  const totalSupply = stats.data?.[2]?.result as bigint | undefined;
  const maxSupply = stats.data?.[3]?.result as bigint | undefined;
  const mintOpen = stats.data?.[4]?.result as boolean | undefined;
  const mintPrice = stats.data?.[5]?.result as bigint | undefined;
  const litCount = stats.data?.[6]?.result as bigint | undefined;
  const igniteFee = stats.data?.[7]?.result as bigint | undefined;
  const available = stats.data?.[8]?.result as bigint | undefined;
  const reserved = stats.data?.[9]?.result as bigint | undefined;
  const threshold = stats.data?.[10]?.result as bigint | undefined;
  const canPulse = stats.data?.[11]?.result as boolean | undefined;
  const epochCount = stats.data?.[12]?.result as bigint | undefined;
  const deliverToTba = stats.data?.[13]?.result as boolean | undefined;
  const bootstrapComplete = stats.data?.[14]?.result as boolean | undefined;
  const ladderIndex = stats.data?.[15]?.result as number | undefined;
  const igniteFeeEth = stats.data?.[16]?.result as bigint | undefined;
  const hopperUnlocked = stats.data?.[17]?.result as boolean | undefined;
  const hopperUnlockTime = stats.data?.[18]?.result as bigint | undefined;

  const busy = isPending || waiting;
  const fill = hopperFill(available, threshold);
  const statsError = stats.isError;

  function refresh() {
    void stats.refetch();
    void tokensQuery.refetch();
    void tokenReads.refetch();
  }

  function run(label: string, fn: () => void) {
    reset();
    setAction(label);
    fn();
  }

  function tokenField(index: number, field: 0 | 1 | 2 | 3) {
    return tokenReads.data?.[index * 4 + field]?.result;
  }

  return (
    <div className="relative min-h-full">
      <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(circle_at_top,_rgba(240,180,41,0.08),_transparent_42%)]" />
      <main className="relative mx-auto flex max-w-6xl flex-col gap-8 px-4 py-8 sm:px-6">
        <section className="max-w-2xl space-y-3">
          <Badge variant="outline" className="font-mono">
            {chain.name} · ETH
          </Badge>
          <h2 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Mint. Ignite. Dial. Hopper. Pulse.
          </h2>
          <p className="text-muted-foreground">
            Terminal Pets mint Sealed with a TBA and a one-time $TERM Ignite
            allotment. Reveal (24h, or sooner if the owner activates) flips
            metadata live, enables Ignite and $TERM trading, and switches
            royalties from 7.5% TermFund to 5% Hopper / 2.5% treasury. Ignite
            is hybrid:
            1,000 $TERM ({SITE.igniteSplit}) plus exactly 0.002 ETH (
            {SITE.igniteEthSplit}). Team earns 0 from that ETH fee. After
            reveal, Hopper ETH comes from 5% of each secondary sale, 50% of
            each Ignite ETH fee, 25% of each Ignite $TERM fee (as ETH when a
            swap router is set), and, once the canonical pool is live, a 1.5%
            TermMarket skim.
            Pulse follows an escalating ETH ladder. Lit earn pro-rata. Dormant
            earn nothing. Dial is assigned at Ignite (1–4 stocks by shell class);
            this screen does not let holders pick. Mint on this hub when{" "}
            <span className="font-mono">mintOpen</span> is true.
          </p>
        </section>

        {!configured && (
          <Card className="border-primary/30">
            <CardHeader>
              <CardTitle>Contracts not configured</CardTitle>
            </CardHeader>
            <CardContent className="space-y-2 text-sm text-muted-foreground">
              <p>
                Deploy with Foundry, then set these in <code>web/.env.local</code>:
              </p>
              <pre className="overflow-x-auto rounded-md bg-background/60 p-3 font-mono text-xs text-foreground">
{`NEXT_PUBLIC_COLLECTION_NFT=
NEXT_PUBLIC_COLLECTION_ADDRESS=
NEXT_PUBLIC_IGNITE_ADDRESS=
NEXT_PUBLIC_HOPPER_ADDRESS=
NEXT_PUBLIC_PULSE_ADDRESS=
NEXT_PUBLIC_SPLITTER_ADDRESS=
NEXT_PUBLIC_TERM_ADDRESS=
NEXT_PUBLIC_TERM_FUND_ADDRESS=
NEXT_PUBLIC_TERM_MARKET_ADDRESS=
NEXT_PUBLIC_CHAIN_ID=4663`}
              </pre>
              <p>
                The UI stays readable without a deployment: connect a wallet,
                then Ignite (allotment $TERM + 0.002 ETH) / Pulse once
                addresses are set. Dial assigns on Ignite in the contracts —
                this screen has no holder picker.
              </p>
            </CardContent>
          </Card>
        )}

        {configured && statsError && (
          <Card className="border-destructive/40">
            <CardHeader>
              <CardTitle>Could not read the chain</CardTitle>
            </CardHeader>
            <CardContent className="text-sm text-muted-foreground">
              Check the RPC, contract addresses, and that you are on {chain.name}.
              <div className="mt-3">
                <Button variant="outline" size="sm" onClick={refresh}>
                  Retry
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        <section className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Stat
            label="Minted"
            value={
              totalSupply !== undefined && maxSupply !== undefined
                ? `${totalSupply.toString()} / ${maxSupply.toString()}`
                : configured
                  ? stats.isLoading
                    ? "Reading…"
                    : "—"
                  : "0 / 4444"
            }
            hint={
              symbol
                ? `${name ?? "Terminal Pets"} (${symbol}) · ${mintAllocation.appHint}`
                : `Terminal Pets (TERM) · ${mintAllocation.appHint}`
            }
          />
          <Stat
            label="Lit"
            value={litCount !== undefined ? litCount.toString() : configured && stats.isLoading ? "Reading…" : "0"}
            hint="Only Lit terminals earn Pulse"
          />
          <Stat
            label="Hopper"
            value={formatEth(available)}
            hint={reserved ? `${formatEth(reserved)} reserved for claims` : "5% royalty + 50% Ignite ETH + live $TERM skim"}
          />
          <Stat
            label="Pulse epochs"
            value={epochCount !== undefined ? epochCount.toString() : "0"}
            hint={deliverToTba ? "Delivery: TBA" : "Delivery: token owner"}
          />
        </section>

        <Card>
          <CardHeader className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <CardTitle>Hopper</CardTitle>
              <p className="text-sm text-muted-foreground">
                No admin sweep. Hopper holds ETH until Pulse at the current
                ladder rung. After reveal, payouts lock {SITE.hopperLock} while
                ETH still accrues. Dialed shares become Stock Tokens; undialed
                shares buy $TERM. Hopper stays ETH.
              </p>
            </div>
            <Button
              onClick={() =>
                run("Pulse", () =>
                  writeContract({
                    address: addresses.pulse,
                    abi: pulseAbi,
                    functionName: "pulse",
                  }),
                )
              }
              disabled={!configured || !onTarget || !canPulse || busy}
            >
              {action === "Pulse" && busy ? "Pulsing…" : "Pulse"}
            </Button>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="flex items-end justify-between font-mono text-xs text-muted-foreground">
              <span>{formatEth(available)} available</span>
              <span>threshold {formatEth(threshold)}</span>
            </div>
            <Progress value={fill} />
            <p className="text-xs text-muted-foreground">
              {hopperUnlocked === false
                ? hopperUnlockTime && hopperUnlockTime > BigInt(0)
                  ? `Payouts locked until ${new Date(Number(hopperUnlockTime) * 1000).toUTCString()}. ETH still accrues. Ignite still works.`
                  : `Payouts lock ${SITE.hopperLock} after reveal. ETH still accrues.`
                : canPulse
                  ? "Hopper is full. Anyone can Pulse."
                  : bootstrapComplete
                    ? "Cycle 0.5–1.0 ETH (never 0.1). Pulse when available ≥ current rung and at least one pet is Lit."
                    : "Bootstrap 0.1→1.0 ETH. Pulse when available ≥ current rung and at least one pet is Lit."}
              {ladderIndex !== undefined
                ? ` Rung index ${ladderIndex}.`
                : ""}
            </p>
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <CardTitle>Dial</CardTitle>
              <p className="text-sm text-muted-foreground">
                Ignite assigns 1–4 Robinhood Chain Stock Tokens (HOOD, AAPL,
                MSFT, GOOGL, AMZN, META, NVDA, TSLA) by shell class. Holders
                do not pick. Unfilled addresses buy $TERM.
              </p>
            </div>
            <ComingSoon>Deploying soon</ComingSoon>
          </CardHeader>
        </Card>

        <section className="space-y-4">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <h3 className="text-xl font-semibold">Your terminals</h3>
              <p className="text-sm text-muted-foreground">
                Ignite Dormant → Lit using the $TERM allotment (or claimed
                tokens) plus 0.002 ETH (50% buy/burn $TERM, 50% Hopper). Claim
                Pulse when an epoch
                includes your Lit pets.
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              <Button variant="outline" asChild>
                <Link href="/mint">Open mint page</Link>
              </Button>
              {configured && mintOpen && isConnected && onTarget && (
                <Button
                  variant="outline"
                  onClick={() =>
                    run("Mint", () =>
                      writeContract({
                        chainId: configuredChainId(),
                        address: addresses.collection,
                        abi: collectionAbi,
                        functionName: "mint",
                        args: [BigInt(1)],
                        value: mintPrice ?? BigInt(0),
                      }),
                    )
                  }
                  disabled={busy}
                >
                  {action === "Mint" && busy ? "Minting…" : `Mint 1 (${formatEth(mintPrice ?? BigInt(0))})`}
                </Button>
              )}
            </div>
          </div>

          {configured && mintOpen === false && (
            <Empty
              title="Mint is closed"
              body={`${mintScheduleCopy.when} CollectionNFT.mintOpen is false, so mint/mintTo revert. Use the mint page when the owner opens the hub path. Do not mint through OpenSea Studio’s deploy wizard.`}
            />
          )}

          {!isConnected && (
            <Empty
              title="Connect a wallet"
              body="Connect to list the terminals you hold, then Ignite or claim Pulse."
            />
          )}

          {isConnected && !onTarget && (
            <Empty
              title="Wrong network"
              body={`Switch to ${chain.name} (chain id ${configuredChainId()}) to read your terminals.`}
            />
          )}

          {isConnected && onTarget && configured && tokensQuery.isLoading && (
            <Empty title="Reading terminals…" body="Asking the collection for tokens you own." />
          )}

          {isConnected && onTarget && configured && tokensQuery.isError && (
            <Empty
              title="Could not list terminals"
              body="The collection call failed. Confirm the address and network, then retry."
            />
          )}

          {isConnected && onTarget && configured && !tokensQuery.isLoading && tokenIds.length === 0 && (
            <Empty
              title="No terminals in this wallet"
              body="Mint on this hub (/mint) when mintOpen is true, then Ignite from here."
            />
          )}

          {tokenIds.length > 0 && (
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
              {tokenIds.map((id, index) => (
                <TokenCard
                  key={id.toString()}
                  tokenId={id}
                  lit={Boolean(tokenField(index, 0))}
                  pending={tokenField(index, 1) as bigint | undefined}
                  tba={tokenField(index, 2) as `0x${string}` | undefined}
                  deliverToTba={deliverToTba}
                  allotmentConsumed={Boolean(tokenField(index, 3))}
                  igniteFee={igniteFee}
                  busy={busy}
                  onIgnite={() =>
                    run(`Ignite #${id}`, () =>
                      writeContract({
                        address: addresses.ignite,
                        abi: igniteAbi,
                        functionName: "ignite",
                        args: [id],
                        value: igniteFeeEth ?? BigInt("5000000000000000"),
                      }),
                    )
                  }
                  onClaimAllotment={() =>
                    run(`Allotment #${id}`, () =>
                      writeContract({
                        address: addresses.ignite,
                        abi: igniteAbi,
                        functionName: "claimIgniteAllotment",
                        args: [id],
                      }),
                    )
                  }
                  onClaim={() =>
                    run(`Claim #${id}`, () =>
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
        </section>

        {(writeError || hash) && (
          <Card>
            <CardContent className="space-y-2 pt-6 text-sm">
              {action && <p className="font-mono text-xs text-muted-foreground">{action}</p>}
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
                  {waiting ? " · confirming" : isSuccess ? " · confirmed" : ""}
                </p>
              )}
            </CardContent>
          </Card>
        )}

        <Separator />

        <footer className="grid gap-6 pb-10 text-sm text-muted-foreground md:grid-cols-3">
          <div>
            <p className="mb-2 font-medium text-foreground">OpenSea</p>
            <p>
              Collection import is separate from mint. Hub mint is the primary
              path. If a collection page exists, point creator earnings to 7.5%
              at the RoyaltySplitter. Pre-reveal that stream is 100% TermFund.
              After reveal it pays 5% of sale to the Hopper and 2.5% to
              treasury. Do not use Studio’s deploy-Drop wizard.
            </p>
          </div>
          <div>
            <p className="mb-2 font-medium text-foreground">Contracts</p>
            {configured ? (
              <ul className="space-y-1 font-mono text-xs">
                <li>
                  <a className="hover:underline" href={explorerAddress(explorer, addresses.collection)}>
                    Collection
                  </a>
                </li>
                <li>
                  <a className="hover:underline" href={explorerAddress(explorer, addresses.ignite)}>
                    Ignite
                  </a>
                </li>
                <li>
                  <a className="hover:underline" href={explorerAddress(explorer, addresses.hopper)}>
                    Hopper
                  </a>
                </li>
                {addresses.splitter !== zeroAddress && (
                  <li>
                    <a className="hover:underline" href={explorerAddress(explorer, addresses.splitter)}>
                      RoyaltySplitter
                    </a>
                  </li>
                )}
                <li>
                  <a className="hover:underline" href={explorerAddress(explorer, addresses.pulse)}>
                    Pulse
                  </a>
                </li>
              </ul>
            ) : (
              <p>Addresses appear here after deploy.</p>
            )}
          </div>
          <div>
            <p className="mb-2 font-medium text-foreground">TBA</p>
            <p>
              Pulse can deliver to the ERC-6551 token-bound account for each
              terminal. Configure the registry after deploy.
            </p>
          </div>
        </footer>
      </main>
    </div>
  );
}

function Stat({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint: string;
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
