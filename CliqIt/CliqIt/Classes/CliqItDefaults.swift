import Foundation

public enum CliqItDefaults {
    /// Admin / match API — SDK always hits this host (not configurable by integrators).
    public static let licenseServerURL = URL(string: "https://api.theblockyapp.com")!
    public static let deferredMatchPath = "api/v1/sdk/app/match"
    /// Direct-link detail lookup — `GET /api/v1/sdk/link/{slug}`.
    public static let linkLookupPath = "api/v1/sdk/link"
    /// SDK key / app identity check — `POST /api/v1/sdk/verify`.
    public static let verifyPath = "api/v1/sdk/verify"
    /// Mobile SDK endpoints require the App SDK API Key in this header.
    public static let apiKeyHeader = "x-api-key"
    public static let apiMaxRetryAttempts = 3
    public static let apiRetryInitialDelay: TimeInterval = 0.5
    /// When `configure(apiKey:)` leaves universal-link domains empty, only this host + subdomains are accepted.
    public static let allowedLinkDomain = "theblockyapp.com"
}

/// Platform identity sent on every SDK API call (same fields as `/sdk/verify`).
enum CliqItSDKIdentity {
    static let platform = "ios"

    static var bundleId: String? {
        Bundle.main.bundleIdentifier
    }

    /// Query items for GET endpoints (e.g. link lookup).
    static var queryItems: [URLQueryItem] {
        var items = [URLQueryItem(name: "platform", value: platform)]
        if let bundleId {
            items.append(URLQueryItem(name: "bundleId", value: bundleId))
        }
        return items
    }

    static func appendQueryIdentity(to url: inout URL) {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        var items = components.queryItems ?? []
        items.append(contentsOf: queryItems)
        components.queryItems = items
        if let updated = components.url {
            url = updated
        }
    }
}
