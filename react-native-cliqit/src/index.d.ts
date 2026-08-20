export type CliqItDeepLinkPayload = {
  url: string;
  path: string;
  pathComponents: string[];
  query: Record<string, string>;
  source: string;
  isDeferred: boolean;
};

export type CliqItDeferredMatchResult =
  | {
      status: 'matched';
      destinationPath?: string | null;
      slug?: string | null;
      tier?: string | null;
      score?: number | null;
      confidence?: string | null;
    }
  | {
      status: 'notMatched';
      tier?: string | null;
      score?: number | null;
    }
  | {
      status: 'failed';
      error: string;
    };

export function configure(apiKey: string): void;
export function handleUrl(url: string): void;
export function onDeepLink(
  listener: (payload: CliqItDeepLinkPayload) => void
): () => void;
export function onDeferredMatch(
  listener: (result: CliqItDeferredMatchResult) => void
): () => void;

declare const _default: {
  configure: typeof configure;
  handleUrl: typeof handleUrl;
  onDeepLink: typeof onDeepLink;
  onDeferredMatch: typeof onDeferredMatch;
};

export default _default;
