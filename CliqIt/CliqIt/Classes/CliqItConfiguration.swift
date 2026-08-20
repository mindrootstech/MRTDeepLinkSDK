import Foundation

public struct CliqItConfiguration: Sendable {
    public let apiKey: String
    public let serverURL: URL
    public let debugLogging: Bool
    public let universalLinkDomain: String?
    public let customURLScheme: String?

    /// Integrators only pass an API key — host / match path / other flags are fixed inside the SDK.
    public init(apiKey: String) {
        self.apiKey = apiKey
        self.serverURL = CliqItDefaults.licenseServerURL
        self.debugLogging = false
        self.universalLinkDomain = nil
        self.customURLScheme = nil
    }

    var deferredMatchPath: String { CliqItDefaults.deferredMatchPath }

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
}
