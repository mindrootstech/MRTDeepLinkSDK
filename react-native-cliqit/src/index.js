import { NativeEventEmitter, NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `react-native-cliqit: native module not linked. ` +
  `Rebuild the iOS app after installing the package (cd ios && pod install).`;

const NativeCliqIt = NativeModules.CliqItModule
  ? NativeModules.CliqItModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

const emitter =
  Platform.OS === 'ios' && NativeModules.CliqItModule
    ? new NativeEventEmitter(NativeModules.CliqItModule)
    : null;

/**
 * @param {string} apiKey
 */
export function configure(apiKey) {
  if (Platform.OS !== 'ios') {
    console.warn('react-native-cliqit: iOS only for now');
    return;
  }
  NativeCliqIt.configure(apiKey);
}

/**
 * Forward a URL (from Linking) into the native SDK.
 * @param {string} url
 */
export function handleUrl(url) {
  if (Platform.OS !== 'ios' || !url) return;
  NativeCliqIt.handleUrl(url);
}

/**
 * @param {(payload: object) => void} listener
 * @returns {() => void} unsubscribe
 */
export function onDeepLink(listener) {
  if (!emitter) return () => {};
  const sub = emitter.addListener('CliqItDeepLink', listener);
  return () => sub.remove();
}

/**
 * @param {(result: object) => void} listener
 * @returns {() => void} unsubscribe
 */
export function onDeferredMatch(listener) {
  if (!emitter) return () => {};
  const sub = emitter.addListener('CliqItDeferredMatch', listener);
  return () => sub.remove();
}

export default {
  configure,
  handleUrl,
  onDeepLink,
  onDeferredMatch,
};
