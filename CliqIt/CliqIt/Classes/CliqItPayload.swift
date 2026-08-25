import Foundation

public enum CliqItSource: String, Sendable {
    case universalLink
    case customScheme
    case deferred
    case unknown
}

/// Unified link / match status — same callback for direct + deferred.
public enum CliqItLinkStatus: String, Sendable {
    /// Direct Universal Link / custom scheme open (navigate with `path`).
    case opened
    /// Deferred fingerprint match (navigate when `path` is non-empty).
    case matched
    /// Deferred ran; no install attribution.
    case notMatched
    /// Deferred match transport / decode failure.
    case failed
    /// `POST /verify` failed or identity mismatch.
    case verifyFailed
    /// Direct slug `GET /link/{slug}` failed (URL path may still be usable).
    case lookupFailed
    /// Match already consumed on this install.
    case alreadyReported
}

/// Known deep-link query keys — use instead of raw string lookups.
public enum CliqItParam: String, CaseIterable, Sendable {
    case session
    case clickSessionId
    case click_session_id
}

/// Single result shape for `onLinkReceived` — direct opens and deferred outcomes share these fields.
public struct CliqItPayload: Sendable, Equatable {
    public let url: URL
    public let path: String
    public let pathComponents: [String]
    public let queryParameters: [String: String]
    public let source: CliqItSource
    public let isDeferred: Bool
    public let receivedAt: Date

    /// `opened` | `matched` | `notMatched` | `failed` | `verifyFailed` | `lookupFailed` | `alreadyReported`
    public let status: CliqItLinkStatus
    /// Deferred only — `true`/`false`; `nil` for direct `opened`.
    public let matched: Bool?
    public let tier: String?
    public let confidence: String?
    public let score: Double?
    public let slug: String?
    /// Server destination when known (equals `path` when navigating).
    public let destinationPath: String?
    public let errorMessage: String?

    public init(
        url: URL,
        path: String,
        pathComponents: [String],
        queryParameters: [String: String],
        source: CliqItSource,
        receivedAt: Date = Date(),
        isDeferred: Bool = false,
        status: CliqItLinkStatus = .opened,
        matched: Bool? = nil,
        tier: String? = nil,
        confidence: String? = nil,
        score: Double? = nil,
        slug: String? = nil,
        destinationPath: String? = nil,
        errorMessage: String? = nil
    ) {
        self.url = url
        self.path = path
        self.pathComponents = pathComponents
        self.queryParameters = queryParameters
        self.source = source
        self.isDeferred = isDeferred
        self.receivedAt = receivedAt
        self.status = status
        self.matched = matched
        self.tier = tier
        self.confidence = confidence
        self.score = score
        self.slug = slug
        self.destinationPath = destinationPath ?? (path.isEmpty ? nil : path)
        self.errorMessage = errorMessage
    }

    public subscript(query key: String) -> String? {
        queryParameters[key]
    }

    public subscript(_ param: CliqItParam) -> String? {
        queryParameters[param.rawValue]
    }

    /// First non-empty session id among known keys.
    public var clickSessionId: String? {
        self[.session] ?? self[.clickSessionId] ?? self[.click_session_id]
    }

    /// True when `path` is non-empty and status is navigable (`opened` / `matched` / `lookupFailed`).
    public var shouldNavigate: Bool {
        !path.isEmpty && (status == .opened || status == .matched || status == .lookupFailed)
    }
}
