import { formatEther } from "viem";

export function shortAddress(value: string) {
  if (!value || value.length < 12) return value;
  return `${value.slice(0, 6)}…${value.slice(-4)}`;
}

export function formatEth(wei: bigint | undefined, digits = 4) {
  if (wei === undefined) return "—";
  const n = Number(formatEther(wei));
  if (!Number.isFinite(n)) return formatEther(wei);
  return `${n.toFixed(digits)} ETH`;
}

/** Trim trailing zeros so 0.002 ETH does not render as 0.0020 ETH. */
export function formatEthTrim(wei: bigint | undefined) {
  if (wei === undefined) return "—";
  const raw = formatEther(wei);
  if (!raw.includes(".")) return `${raw} ETH`;
  const trimmed = raw.replace(/0+$/, "").replace(/\.$/, "");
  return `${trimmed} ETH`;
}

export function formatTerm(wei: bigint | undefined) {
  if (wei === undefined) return "—";
  const n = Number(formatEther(wei));
  if (!Number.isFinite(n)) return `${formatEther(wei)} $TERM`;
  return `${n.toLocaleString("en-US", { maximumFractionDigits: 2 })} $TERM`;
}

export function formatUnixUtc(seconds?: bigint) {
  if (seconds === undefined || seconds <= BigInt(0)) return null;
  const date = new Date(Number(seconds) * 1000);
  if (Number.isNaN(date.getTime())) return null;
  return (
    new Intl.DateTimeFormat("en-US", {
      dateStyle: "long",
      timeStyle: "short",
      timeZone: "UTC",
    }).format(date) + " UTC"
  );
}

export function payoutLockCopy(unlocked?: boolean, unlockTime?: bigint) {
  if (unlocked) return "Payouts are open.";
  const when = formatUnixUtc(unlockTime);
  if (when) return `Payouts open ${when}.`;
  if (unlocked === undefined) return "Checking when payouts open…";
  return "Payouts open 7 days after the collection was revealed.";
}

export function explorerAddress(base: string, address: string) {
  return `${base.replace(/\/$/, "")}/address/${address}`;
}

export function explorerTx(base: string, hash: string) {
  return `${base.replace(/\/$/, "")}/tx/${hash}`;
}
