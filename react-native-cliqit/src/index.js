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

function invoke(callback, payload) {
  if (typeof callback !== 'function') return;
  callback({
    result: payload.result ?? null,
    error: payload.error ?? null,
  });
}

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

const CliqIt = {
  LinkField,

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
   * Only public listener — direct, deferred, verify/lookup errors.
   * @returns {() => void} unsubscribe
   */
  onLinkReceived(callback) {
    if (typeof callback !== 'function') {
      throw new Error('CliqIt.onLinkReceived: pass ({ result, error }) => { ... }');
    }
    const sub = emitter.addListener('CliqItLinkReceived', (raw) => {
      callback(mapLinkReceived(raw));
    });
    return () => sub.remove();
  },
};

export default CliqIt;
