import Foundation

public enum CliqItSource: String, Sendable {
    case universalLink
    case customScheme
    case deferred
    case unknown
}

/// Known deep-link query keys — use instead of raw string lookups.
public enum CliqItParam: String, CaseIterable, Sendable {
    case session
    case clickSessionId
    case click_session_id
}

public struct CliqItPayload: Sendable, Equatable {
    public let url: URL
    public let path: String
    public let pathComponents: [String]
    public let queryParameters: [String: String]
    public let source: CliqItSource
    public let isDeferred: Bool
    public let receivedAt: Date

    public init(
        url: URL,
        path: String,
        pathComponents: [String],
        queryParameters: [String: String],
        source: CliqItSource,
        receivedAt: Date = Date(),
        isDeferred: Bool = false
    ) {
        self.url = url
        self.path = path
        self.pathComponents = pathComponents
        self.queryParameters = queryParameters
        self.source = source
        self.isDeferred = isDeferred
        self.receivedAt = receivedAt
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
}
