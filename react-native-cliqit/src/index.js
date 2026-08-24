import { NativeEventEmitter, NativeModules } from 'react-native';

const LINKING_ERROR =
  `CliqIt native module not found. Make sure the native module is linked (iOS pod / Android cliqit-native).`;

const NativeCliqIt = NativeModules.CliqItModule
  ? NativeModules.CliqItModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      },
    );

const emitter = new NativeEventEmitter(NativeCliqIt);

/** Mirrors native `CliqItLinkField` — use `details[LinkField.resolvedPath]`. */
export const LinkField = NativeCliqIt.LinkField ?? {
  destination: 'destination',
  iosDestination: 'iosDestination',
  androidDestination: 'androidDestination',
  ogTitle: 'ogTitle',
  ogDescription: 'ogDescription',
  ogImage: 'ogImage',
  ogUrl: 'ogUrl',
  slug: 'slug',
  webFallback: 'webFallback',
  showInterstitial: 'showInterstitial',
  isDeepLink: 'isDeepLink',
  appleTeamId: 'appleTeamId',
  iosBundleId: 'iosBundleId',
  androidPackageName: 'androidPackageName',
  resolvedPath: 'resolvedPath',
};

/** @param {{ result?: any, error?: string | null }} payload */
function invoke(callback, payload) {
  if (typeof callback !== 'function') return;
  callback({
    result: payload.result ?? null,
    error: payload.error ?? null,
  });
}

function listen(eventName, mapRaw, callback) {
  if (typeof callback !== 'function') {
    throw new Error(`CliqIt.${eventName}: pass ({ result, error }) => { ... }`);
  }
  const sub = emitter.addListener(eventName, (raw) => {
    callback(mapRaw(raw));
  });
  return () => sub.remove();
}

/** Unified direct + deferred payload. Failures set `error`. */
function mapLinkReceived(raw) {
  if (!raw) return { result: null, error: 'Empty link payload' };
  const failStatuses = new Set(['failed', 'verifyFailed', 'lookupFailed']);
  if (failStatuses.has(raw.status)) {
    return {
      result: raw,
      error: raw.error || `Link failed (${raw.status})`,
    };
  }
  return { result: raw, error: null };
}

function mapLinkLookup(raw) {
  if (!raw) return { result: null, error: 'Empty link lookup payload' };
  if (raw.status === 'failed') {
    return { result: null, error: raw.error || 'Link lookup failed' };
  }
  return { result: raw, error: null };
}

function mapVerify(raw) {
  if (!raw) return { result: null, error: 'Empty verify payload' };
  if (raw.status === 'failed') {
    return { result: null, error: raw.error || raw.message || 'Verify failed' };
  }
  return { result: raw, error: null };
}

const CliqIt = {
  LinkField,

  /**
   * @param {{ apiKey: string }} options
   * @param {(payload: { result: { ok: true } | null, error: string | null }) => void} [callback]
   */
  configure(options = {}, callback) {
    const apiKey = options?.apiKey;
    if (!apiKey || typeof apiKey !== 'string') {
      invoke(callback, { result: null, error: 'apiKey is required' });
      return;
    }
    try {
      NativeCliqIt.configure(apiKey);
      invoke(callback, { result: { ok: true }, error: null });
    } catch (e) {
      invoke(callback, {
        result: null,
        error: e?.message || String(e),
      });
    }
  },

  /**
   * @param {{ url: string }} options
   * @param {(payload: { result: { ok: true, url: string } | null, error: string | null }) => void} [callback]
   */
  handleUrl(options = {}, callback) {
    const url = options?.url;
    if (!url || typeof url !== 'string') {
      invoke(callback, { result: null, error: 'url is required' });
      return;
    }
    try {
      NativeCliqIt.handleUrl(url);
      invoke(callback, { result: { ok: true, url }, error: null });
    } catch (e) {
      invoke(callback, {
        result: null,
        error: e?.message || String(e),
      });
    }
  },

  /**
   * Direct opens + deferred match + verify/lookup errors (same fields).
   * Verify + slug lookup run in the background — only listen here.
   * @param {(payload: { result: object | null, error: string | null }) => void} callback
   */
  onLinkReceived(callback) {
    return listen('CliqItLinkReceived', mapLinkReceived, callback);
  },

  /**
   * @deprecated Use onLinkReceived
   * @param {(payload: { result: object | null, error: string | null }) => void} callback
   */
  onDeepLink(callback) {
    return CliqIt.onLinkReceived(callback);
  },

  /**
   * @deprecated Use onLinkReceived
   * @param {(payload: { result: object | null, error: string | null }) => void} callback
   */
  onDeferredMatch(callback) {
    if (typeof callback !== 'function') {
      throw new Error('CliqIt.onDeferredMatch: pass ({ result, error }) => { ... }');
    }
    const sub = emitter.addListener('CliqItLinkReceived', (raw) => {
      if (!raw?.isDeferred && raw?.status !== 'alreadyReported') return;
      callback(mapLinkReceived(raw));
    });
    return () => sub.remove();
  },

  /**
   * @deprecated Use onLinkReceived — slug lookup is background; failures arrive as status lookupFailed.
   * @param {(payload: { result: object | null, error: string | null }) => void} callback
   */
  onLinkLookup(callback) {
    return listen('CliqItLinkLookup', mapLinkLookup, callback);
  },

  /**
   * @deprecated Use onLinkReceived — verify is background; failures arrive as status verifyFailed.
   * @param {(payload: { result: object | null, error: string | null }) => void} callback
   */
  onVerify(callback) {
    return listen('CliqItVerify', mapVerify, callback);
  },
};

export default CliqIt;
