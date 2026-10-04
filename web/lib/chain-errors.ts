const RULES: { test: RegExp; message: string }[] = [
  {
    test: /user rejected|user denied|denied transaction|rejected the request/i,
    message: "You cancelled in the wallet. Nothing was charged.",
  },
  {
    test: /IgniteClosed/i,
    message: "Ignite isn't open yet. You can try again once waking pets is enabled.",
  },
  {
    test: /WrongEthFee/i,
    message:
      "The ETH amount didn't match the Ignite fee. Refresh the page and try again.",
  },
  {
    test: /NotTokenOwner/i,
    message: "This pet isn't in the wallet you have connected.",
  },
  {
    test: /AlreadyLit/i,
    message: "This pet is already awake.",
  },
  {
    test: /AllotmentConsumed/i,
    message:
      "The $TERM for this egg was already taken out. Approve $TERM, then Ignite.",
  },
  {
    test: /InsufficientAllotment/i,
    message:
      "The $TERM inside this egg isn't available right now. Try again in a moment.",
  },
  {
    test: /insufficient funds|exceeds the balance|insufficient balance/i,
    message:
      "This wallet needs a little more ETH on Robinhood Chain for the Ignite fee and gas.",
  },
  {
    test: /insufficient allowance|ERC20InsufficientAllowance/i,
    message: "Approve $TERM for this pet, then Ignite.",
  },
  {
    test: /ChainMismatch|chain mismatch|wrong network|Unrecognized chain/i,
    message: "Switch your wallet to Robinhood Chain (chain id 4663), then try again.",
  },
  {
    test: /ConnectorNotFound|ProviderNotFound|provider not found|no ethereum/i,
    message: "No wallet was found in this browser.",
  },
];

function errorText(error: unknown) {
  if (!error) return "";
  if (typeof error === "string") return error;
  if (typeof error !== "object") return String(error);
  const row = error as { shortMessage?: unknown; message?: unknown; details?: unknown };
  return [row.shortMessage, row.details, row.message].filter(Boolean).join(" ");
}

export function friendlyChainError(error: unknown) {
  const text = errorText(error);
  for (const rule of RULES) {
    if (rule.test.test(text)) return rule.message;
  }
  return "That didn't go through. Check your wallet and try again.";
}

export function technicalChainError(error: unknown) {
  if (!error || typeof error !== "object") return "";
  const row = error as { shortMessage?: unknown; message?: unknown };
  if (typeof row.shortMessage === "string" && row.shortMessage.trim()) {
    return row.shortMessage.trim();
  }
  if (typeof row.message === "string") return row.message.trim();
  return "";
}
