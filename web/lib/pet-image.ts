type Attribute = { trait_type?: string; value?: string };

export type PetMeta = {
  image: string | null;
  title: string | null;
};

export function normalizeUri(uri: string) {
  const trimmed = uri.trim();
  if (trimmed.startsWith("ipfs://ipfs/")) {
    return `https://ipfs.io/ipfs/${trimmed.slice("ipfs://ipfs/".length)}`;
  }
  if (trimmed.startsWith("ipfs://")) {
    return `https://ipfs.io/ipfs/${trimmed.slice("ipfs://".length)}`;
  }
  if (
    trimmed.startsWith("https://") ||
    trimmed.startsWith("http://") ||
    trimmed.startsWith("data:")
  ) {
    return trimmed;
  }
  return null;
}

function dataJson(uri: string): Record<string, unknown> | null {
  const comma = uri.indexOf(",");
  if (comma < 0) return null;
  const meta = uri.slice(0, comma);
  const payload = uri.slice(comma + 1);
  try {
    const text = meta.includes(";base64")
      ? atob(payload)
      : decodeURIComponent(payload);
    const parsed = JSON.parse(text) as unknown;
    return parsed && typeof parsed === "object"
      ? (parsed as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

function titleFrom(record: Record<string, unknown>) {
  const attributes = Array.isArray(record.attributes)
    ? (record.attributes as Attribute[])
    : [];
  const pet = attributes.find((item) => item.trait_type === "Pet")?.value;
  if (pet) return pet;
  return typeof record.name === "string" ? record.name : null;
}

export async function resolvePetMeta(tokenUri: string): Promise<PetMeta> {
  const url = normalizeUri(tokenUri);
  if (!url) return { image: null, title: null };
  try {
    const json = url.startsWith("data:application/json")
      ? dataJson(url)
      : await fetch(url).then(async (res) => {
          if (!res.ok) return null;
          return (await res.json()) as Record<string, unknown>;
        });
    if (!json) return { image: null, title: null };
    const image =
      typeof json.image === "string" ? normalizeUri(json.image) : null;
    return { image, title: titleFrom(json) };
  } catch {
    return { image: null, title: null };
  }
}
