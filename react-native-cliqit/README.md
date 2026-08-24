# react-native-cliqit

```bash
npm install github:mindrootstech/react-native-cliqit#unify-onDeepLink-2.0.7
cd ios && pod install && cd ..
```

## API (only this)

```js
import CliqIt from 'react-native-cliqit';
import { Linking } from 'react-native';

const off = CliqIt.onLinkReceived(({ result, error }) => {
  if (error) {
    console.warn(error, result?.status); // failed | verifyFailed | lookupFailed
    return;
  }
  if (result?.shouldNavigate) {
    // navigate result.path
  }
});

CliqIt.configure({ apiKey: 'pk_live_…' });
Linking.getInitialURL().then((url) => url && CliqIt.handleUrl({ url }));
Linking.addEventListener('url', ({ url }) => CliqIt.handleUrl({ url }));
```

Verify / slug lookup / deferred match run in the background.
