import Foundation

public struct MRTDeepLinkRemoteConfig: Sendable {
    public let appIdentifier: String
    public let universalLinkDomains: [String]
    public let customURLSchemes: [String]
}

public struct MRTDeepLinkConfiguration: Sendable {
    public let apiKey: String
    public let licenseServerURL: URL
    public let licenseValidationPath: String
    public let debugLogging: Bool

    var appIdentifier: String
    var universalLinkDomains: [String]
    var customURLSchemes: [String]

    /// Pass only your API key — domains, scheme, and bundle ID come from the admin server.
    public init(
        apiKey: String,
        debugLogging: Bool = false,
        licenseServerURL: URL = MRTDeepLinkDefaults.licenseServerURL,
        licenseValidationPath: String = MRTDeepLinkDefaults.licenseValidationPath
    ) {
        self.apiKey = apiKey
        self.licenseServerURL = licenseServerURL
        self.licenseValidationPath = licenseValidationPath
        self.debugLogging = debugLogging
        self.appIdentifier = Bundle.main.bundleIdentifier ?? ""
        self.universalLinkDomains = []
        self.customURLSchemes = []
    }

    var isRemoteConfigLoaded: Bool {
        !appIdentifier.isEmpty
    }

    func applyingRemoteConfig(_ remote: MRTDeepLinkRemoteConfig) -> MRTDeepLinkConfiguration {
        var updated = self
        updated.appIdentifier = remote.appIdentifier
        updated.universalLinkDomains = remote.universalLinkDomains
        updated.customURLSchemes = remote.customURLSchemes
        return updated
    }
}
