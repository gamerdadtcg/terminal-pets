"use client";

import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  friendlyChainError,
  technicalChainError,
} from "@/lib/chain-errors";
import { activeChain, configuredChainId, explorerUrl } from "@/lib/chain";
import {
  addresses,
  contractsConfigured,
  hopperAbi,
  pulseAbi,
} from "@/lib/contracts";
import { explorerTx, formatEthTrim, payoutLockCopy } from "@/lib/format";
import Link from "next/link";
import { useState } from "react";
import {
  useAccount,
  useReadContract,
  useWaitForTransactionReceipt,
  useWriteContract,
} from "wagmi";

export function HopperStatus() {
  const configured = contractsConfigured();
  const { isConnected, chainId } = useAccount();
  const onTarget = chainId === configuredChainId();
  const chain = activeChain();
  const explorer = explorerUrl();
  const available = useReadContract({
    address: addresses.hopper,
    abi: hopperAbi,
    functionName: "available",
    query: { enabled: configured, refetchInterval: 12_000 },
  });
  const unlocked = useReadContract({
    address: addresses.hopper,
    abi: hopperAbi,
    functionName: "hopperUnlocked",
    query: { enabled: configured },
  });
  const unlockTime = useReadContract({
    address: addresses.hopper,
    abi: hopperAbi,
    functionName: "hopperUnlockTime",
    query: { enabled: configured },
  });
  const threshold = useReadContract({
    address: addresses.pulse,
    abi: pulseAbi,
    functionName: "pulseThreshold",
    query: { enabled: configured, refetchInterval: 12_000 },
  });
  const canPulse = useReadContract({
    address: addresses.pulse,
    abi: pulseAbi,
    functionName: "canPulse",
    query: { enabled: configured, refetchInterval: 12_000 },
  });
  const { writeContract, data: hash, isPending, error, reset } = useWriteContract();
  const { isLoading: waiting, isSuccess } = useWaitForTransactionReceipt({ hash });
  const [ran, setRan] = useState(false);
  const busy = isPending || waiting;
  const ready = Boolean(canPulse.data);
  const payoutCopy = payoutLockCopy(unlocked.data, unlockTime.data);

  return (
    <Card className="border-primary/30">
      <CardHeader>
        <CardTitle className="text-base">Right now</CardTitle>
      </CardHeader>
      <CardContent className="space-y-3 text-sm text-muted-foreground">
        <p className="font-mono text-2xl text-foreground">
          {formatEthTrim(available.data)}
        </p>
        <p>In the Hopper. Next payout needs {formatEthTrim(threshold.data)}.</p>
        <p>{configured ? payoutCopy : "Contracts aren't configured in this build."}</p>
        {ready ? (
          <p>The pot is large enough for a payout.</p>
        ) : (
          <p>A payout cannot run until the pot reaches the current rung and the lock is over.</p>
        )}
        {!isConnected && (
          <p>
            Connect a wallet on {chain.name} if you want to run the payout
            yourself. You can also just wait. Collect on{" "}
            <Link className="underline-offset-2 hover:underline" href="/">
              your pet
            </Link>{" "}
            when something is waiting.
          </p>
        )}
        {isConnected && !onTarget && (
          <p>Switch to {chain.name} before running a payout.</p>
        )}
        <Button
          className="w-full"
          variant="outline"
          disabled={!configured || !onTarget || !ready || busy}
          onClick={() => {
            reset();
            setRan(true);
            writeContract({
              address: addresses.pulse,
              abi: pulseAbi,
              functionName: "pulse",
            });
          }}
        >
          {busy ? "Running payout…" : "Run payout"}
        </Button>
        {error && (
          <div className="space-y-1">
            <p className="text-destructive">{friendlyChainError(error)}</p>
            <p className="font-mono text-xs">{technicalChainError(error)}</p>
          </div>
        )}
        {hash && (
          <p>
            <a
              className="underline-offset-2 hover:underline"
              href={explorerTx(explorer, hash)}
              target="_blank"
              rel="noreferrer"
            >
              {waiting ? "Confirming payout…" : isSuccess ? "Payout confirmed" : "Payout sent"}
            </a>
          </p>
        )}
        {ran && isSuccess && (
          <p>Payout sent. Awake pets can collect from the Ignite page.</p>
        )}
      </CardContent>
    </Card>
  );
}
