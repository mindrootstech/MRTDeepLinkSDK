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

  const offDeepLink = CliqIt.onDeepLink((payload) => {
    console.log('deep link', payload.path, payload.isDeferred);
  });

  const offMatch = CliqIt.onDeferredMatch((result) => {
    if (result.status === 'matched') {
      console.log('deferred', result.destinationPath);
    }
  });

  Linking.getInitialURL().then((url) => {
    if (url) CliqIt.handleUrl(url);
  });
  const linkSub = Linking.addEventListener('url', ({ url }) => {
    CliqIt.handleUrl(url);
  });

  return () => {
    offDeepLink();
    offMatch();
    linkSub.remove();
  };
}, []);
```

## Notes

- Deferred match returns `destinationPath` / `slug`, not the original short URL.
- iOS 15+.
