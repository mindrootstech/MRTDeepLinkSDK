export type CliqItDeepLinkPayload = {
  url: string;
  path: string;
  pathComponents: string[];
  query: Record<string, string>;
  source: string;
  isDeferred: boolean;
  status: 'opened' | 'matched' | 'notMatched' | 'failed' | 'alreadyReported' | string;
  matched?: boolean | null;
  tier?: string | null;
  confidence?: string | null;
  score?: number | null;
  slug?: string | null;
  destinationPath?: string | null;
  error?: string | null;
  shouldNavigate?: boolean;
};

/** @deprecated Use CliqItDeepLinkPayload */
export type CliqItDeferredMatchResult = CliqItDeepLinkPayload;

export function configure(apiKey: string): void;
export function handleUrl(url: string): void;
export function onDeepLink(
  listener: (payload: CliqItDeepLinkPayload) => void
): () => void;
/** @deprecated Use onDeepLink */
export function onDeferredMatch(
  listener: (result: CliqItDeepLinkPayload) => void
): () => void;

declare const _default: {
  configure: typeof configure;
  handleUrl: typeof handleUrl;
  onDeepLink: typeof onDeepLink;
  onDeferredMatch: typeof onDeferredMatch;
};

export default _default;
