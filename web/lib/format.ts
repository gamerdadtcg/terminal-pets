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

export function explorerAddress(base: string, address: string) {
  return `${base.replace(/\/$/, "")}/address/${address}`;
}

export function explorerTx(base: string, hash: string) {
  return `${base.replace(/\/$/, "")}/tx/${hash}`;
}
