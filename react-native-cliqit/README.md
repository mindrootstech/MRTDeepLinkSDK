# react-native-cliqit

React Native bridge for **CliqIt** deferred deep linking (iOS + Android).

```bash
npm install github:mindrootstech/react-native-cliqit#unify-onDeepLink-2.0.7
cd ios && pod install && cd ..
```

Rebuild the native app after upgrading.

## Usage

All listeners use **`({ result, error })`**.

```js
import { useEffect } from 'react';
import { Linking } from 'react-native';
import CliqIt from 'react-native-cliqit';

useEffect(() => {
  const off = CliqIt.onLinkReceived(({ result, error }) => {
    if (error) {
      // Transport / failed status — also see result?.error when status === 'failed'
      console.warn(error);
      return;
    }
    // status: opened | matched | notMatched | failed | alreadyReported
    if (result?.shouldNavigate) {
      // navigate to result.path
    }
  });

  CliqIt.configure({ apiKey: 'pk_live_…' });

  Linking.getInitialURL().then((url) => url && CliqIt.handleUrl({ url }));
  const sub = Linking.addEventListener('url', ({ url }) => CliqIt.handleUrl({ url }));

  return () => {
    off();
    sub.remove();
  };
}, []);
```

## Callback envelope

Every listener / callback:

| Field | Type | Notes |
|-------|------|--------|
| `result` | `object \| null` | Payload when available |
| `error` | `string \| null` | Set on failure (`status: failed`, empty event, configure/handleUrl validation, …) |

## `onLinkReceived` → `result` fields

| Field | Notes |
|-------|--------|
| `status` | `opened` \| `matched` \| `notMatched` \| `failed` \| `alreadyReported` |
| `path` / `destinationPath` | In-app path (empty when nothing to open) |
| `isDeferred` | `true` for deferred outcomes |
| `shouldNavigate` | `true` when you should route |
| `matched` / `slug` / `tier` / `score` / `confidence` | Deferred attribution |
| `url` / `source` / `query` / `pathComponents` | Common link fields |
| `error` | Message when `status === 'failed'` (native `errorMessage`) |

`onDeepLink` / `onDeferredMatch` are **deprecated** aliases.

Also: `onLinkLookup`, `onVerify`, `LinkField`.

## Notes

- iOS ships `CliqIt.xcframework` in this package.
- iOS 15+.
