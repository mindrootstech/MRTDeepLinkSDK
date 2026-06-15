import Foundation

public enum MRTDeepLinkSource: String, Sendable {
    case universalLink
    case customScheme
    case unknown
}

public struct MRTDeepLinkPayload: Sendable, Equatable {
    public let url: URL
    public let path: String
    public let pathComponents: [String]
    public let queryParameters: [String: String]
    public let source: MRTDeepLinkSource
    public let receivedAt: Date

    public init(
        url: URL,
        path: String,
        pathComponents: [String],
        queryParameters: [String: String],
        source: MRTDeepLinkSource,
        receivedAt: Date = Date()
    ) {
        self.url = url
        self.path = path
        self.pathComponents = pathComponents
        self.queryParameters = queryParameters
        self.source = source
        self.receivedAt = receivedAt
    }

    public subscript(query key: String) -> String? {
        queryParameters[key]
    }
}
