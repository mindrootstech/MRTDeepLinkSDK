import Foundation

public struct MRTDeepLinkConfiguration: Sendable {
    public let apiKey: String
    public let serverURL: URL
    public let debugLogging: Bool
    public let universalLinkDomain: String?
    public let customURLScheme: String?
    /// When true, deferred match silently checks the clipboard for a copied SmartLink
    /// (no prompt) and only reads it (one iOS paste prompt) if a web URL is present.
    /// Off by default because the read can show the system paste prompt.
    public let clipboardMatchEnabled: Bool

    public init(
        apiKey: String,
        debugLogging: Bool = false,
        serverURL: URL = MRTDeepLinkDefaults.licenseServerURL,
        universalLinkDomain: String? = nil,
        customURLScheme: String? = nil,
        clipboardMatchEnabled: Bool = false
    ) {
        self.apiKey = apiKey
        self.serverURL = serverURL
        self.debugLogging = debugLogging
        self.universalLinkDomain = Self.normalizedDomain(universalLinkDomain)
        self.customURLScheme = customURLScheme
        self.clipboardMatchEnabled = clipboardMatchEnabled
    }

    var deferredMatchPath: String { MRTDeepLinkDefaults.deferredMatchPath }

    var universalLinkDomains: [String] {
        universalLinkDomain.map { [$0] } ?? []
    }

    var customURLSchemes: [String] {
        customURLScheme.map { [$0] } ?? []
    }

    var primaryLinkDomain: String? {
        universalLinkDomain ?? serverURL.host
    }

    var fingerprintProbeDomain: String? {
        primaryLinkDomain
    }

    private static func normalizedDomain(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.hasPrefix("http://") || value.hasPrefix("https://"),
           let host = URL(string: value)?.host {
            return host
        }
        return value
    }
}
