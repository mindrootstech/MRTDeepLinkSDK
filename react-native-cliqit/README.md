# react-native-cliqit

React Native bridge for **CliqIt** deferred deep linking.

- **iOS:** ships `CliqIt.xcframework` inside this package (no separate CliqIt pod line needed)
- **Android:** stub only for now

## Install

```bash
npm install react-native-cliqit
# or local:
# npm install ../MRTDeepLink/react-native-cliqit

cd ios && pod install && cd ..
```

Rebuild the iOS app after install.

## Usage

```js
import { useEffect } from 'react';
import { Linking } from 'react-native';
import CliqIt from 'react-native-cliqit';

useEffect(() => {
  CliqIt.configure('pk_live_…');

  const offLink = CliqIt.onLinkReceived((payload) => {
    // Direct + deferred share the same fields
    console.log(payload.status, payload.path, payload.isDeferred, payload.slug);
    if (payload.shouldNavigate) {
      // navigate to payload.path
    }
  });

  Linking.getInitialURL().then((url) => {
    if (url) CliqIt.handleUrl(url);
  });
  const linkSub = Linking.addEventListener('url', ({ url }) => {
    CliqIt.handleUrl(url);
  });

  return () => {
    offLink();
    linkSub.remove();
  };
}, []);
```

## Notes

- One listener: `onLinkReceived` — `status` is `opened` | `matched` | `notMatched` | `failed` | `alreadyReported`.
- Navigate when `shouldNavigate` (or non-empty `path` + opened/matched).
- iOS 15+.
