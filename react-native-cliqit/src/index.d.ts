export type CliqItCallbackPayload<T = any> = {
  result: T | null;
  error: string | null;
};

export type CliqItCallback<T = any> = (
  payload: CliqItCallbackPayload<T>
) => void;

export type CliqItLinkReceivedPayload = {
  url: string;
  path: string;
  pathComponents: string[];
  query: Record<string, string>;
  source: string;
  isDeferred: boolean;
  status:
    | 'opened'
    | 'matched'
    | 'notMatched'
    | 'failed'
    | 'verifyFailed'
    | 'lookupFailed'
    | 'alreadyReported'
    | string;
  matched?: boolean | null;
  tier?: string | null;
  confidence?: string | null;
  score?: number | null;
  slug?: string | null;
  destinationPath?: string | null;
  error?: string | null;
  shouldNavigate?: boolean;
};

export const LinkField: Record<string, string>;

export function configure(
  options: { apiKey: string },
  callback?: CliqItCallback<{ ok: true }>
): void;

export function handleUrl(
  options: { url: string },
  callback?: CliqItCallback<{ ok: true; url: string }>
): void;

export function onLinkReceived(
  callback: CliqItCallback<CliqItLinkReceivedPayload>
): () => void;

declare const _default: {
  LinkField: typeof LinkField;
  configure: typeof configure;
  handleUrl: typeof handleUrl;
  onLinkReceived: typeof onLinkReceived;
};

export default _default;
