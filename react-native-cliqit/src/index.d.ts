export type CliqItCallbackPayload<T = any> = {
  result: T | null;
  error: string | null;
};

export type CliqItCallback<T = any> = (
  payload: CliqItCallbackPayload<T>
) => void;

/** Unified direct + deferred result (same fields every time). */
export type CliqItLinkReceivedPayload = {
  url: string;
  path: string;
  pathComponents: string[];
  query: Record<string, string>;
  source: string;
  isDeferred: boolean;
  /** opened | matched | notMatched | failed | verifyFailed | lookupFailed | alreadyReported */
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

/** @deprecated Use CliqItLinkReceivedPayload */
export type CliqItDeepLinkPayload = CliqItLinkReceivedPayload;
/** @deprecated Use CliqItLinkReceivedPayload */
export type CliqItDeferredMatchResult = CliqItLinkReceivedPayload;

export type CliqItLinkLookupResult = {
  status: 'resolved';
  [key: string]: any;
};

export type CliqItVerifyResult = {
  status: 'ok' | 'mismatch';
  ok?: boolean;
  appId?: string | null;
  appName?: string | null;
  message?: string;
  checks?: Record<string, { actual?: string; expected?: string; match?: boolean }>;
  raw?: string;
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

/** @deprecated Use onLinkReceived */
export function onDeepLink(
  callback: CliqItCallback<CliqItLinkReceivedPayload>
): () => void;

/** @deprecated Use onLinkReceived */
export function onDeferredMatch(
  callback: CliqItCallback<CliqItLinkReceivedPayload>
): () => void;

/** @deprecated Use onLinkReceived */
export function onLinkLookup(
  callback: CliqItCallback<CliqItLinkLookupResult>
): () => void;

/** @deprecated Use onLinkReceived */
export function onVerify(
  callback: CliqItCallback<CliqItVerifyResult>
): () => void;

declare const _default: {
  LinkField: typeof LinkField;
  configure: typeof configure;
  handleUrl: typeof handleUrl;
  onLinkReceived: typeof onLinkReceived;
  onDeepLink: typeof onDeepLink;
  onDeferredMatch: typeof onDeferredMatch;
  onLinkLookup: typeof onLinkLookup;
  onVerify: typeof onVerify;
};

export default _default;
