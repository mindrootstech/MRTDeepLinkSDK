# Smart Link Web (iOS)

Host this folder on your server so that when a user taps a link:

1. **App installed** → opens the app (Universal Link or custom scheme)
2. **App not installed** → redirects to the App Store

## Deployment

### 1. Domain setup

Example: `links.yourdomain.com`

### 2. Upload files

```
index.html                               → site root (serve for all paths)
.well-known/apple-app-site-association   → https://domain/.well-known/apple-app-site-association
```

> **Important:** Serve `apple-app-site-association` without a `.json` extension and with `Content-Type: application/json`.

### 3. Nginx example (all paths → index.html)

```nginx
server {
    listen 443 ssl;
    server_name links.yourdomain.com;

    location /.well-known/ {
        root /var/www/smartlink;
    }

    location / {
        root /var/www/smartlink;
        try_files $uri /index.html;
    }
}
```

### 4. Update `index.html` CONFIG

- `customScheme` — iOS app URL scheme
- `iosAppStore` — App Store URL

### 5. Update `apple-app-site-association`

- Replace `TEAM_ID` with your Apple Developer Team ID
- Replace bundle ID with your iOS app identifier

### 6. Xcode (iOS app)

Signing & Capabilities → Associated Domains:

```
applinks:links.yourdomain.com
```

## Test links

```
https://links.yourdomain.com/product/42?id=abc
https://links.yourdomain.com/profile/99
```

## Flow

```
User taps https://links.yourdomain.com/product/42
        │
        ├─ iOS + app installed + Universal Links configured → app opens directly
        │
        └─ App not installed / opened in browser → index.html
                └─ iOS → yourapp://product/42 → timeout → App Store
```
