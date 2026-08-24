# react-native-cliqit

React Native bridge for **CliqIt** deferred deep linking (iOS + Android).

```bash
npm install github:mindrootstech/react-native-cliqit#unify-onDeepLink-2.0.7
cd ios && pod install && cd ..
```

## Usage — one listener

`configure` + `handleUrl` + **`onLinkReceived`**.  
Verify, slug lookup, and deferred match all run in the background. You only get navigation results and errors here.

```js
import { useEffect } from 'react';
import { Linking } from 'react-native';
import CliqIt from 'react-native-cliqit';

useEffect(() => {
  const off = CliqIt.onLinkReceived(({ result, error }) => {
    if (error) {
      // status: failed | verifyFailed | lookupFailed (see result?.status)
      console.warn(error, result?.status);
      return;
    }
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

| Field | Type | Notes |
|-------|------|--------|
| `result` | `object \| null` | Payload when available |
| `error` | `string \| null` | Set for `failed` / `verifyFailed` / `lookupFailed` |

## `result` fields

| Field | Notes |
|-------|--------|
| `status` | `opened` \| `matched` \| `notMatched` \| `failed` \| `verifyFailed` \| `lookupFailed` \| `alreadyReported` |
| `path` / `destinationPath` | In-app path |
| `shouldNavigate` | Route when `true` (`opened` / `matched` / `lookupFailed` with path) |
| `isDeferred` | Deferred outcomes |
| `matched` / `slug` / `tier` / `score` / `confidence` | Attribution |
| `url` / `source` / `query` / `pathComponents` | Link fields |
| `error` | Detail when a failure status is set |

**Background (no separate listener needed):** API verify after configure; slug → destination on direct SmartLink open; deferred fingerprint match.

Deprecated: `onDeepLink`, `onDeferredMatch`, `onLinkLookup`, `onVerify`.

## Notes

- iOS ships `CliqIt.xcframework` in this package.
- iOS 15+.
