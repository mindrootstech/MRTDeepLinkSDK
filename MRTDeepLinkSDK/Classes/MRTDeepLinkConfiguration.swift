import Foundation

public struct MRTDeepLinkConfiguration: Sendable {
    public let appIdentifier: String
    public let apiKey: String
    public let licenseServerURL: URL
    public let licenseValidationPath: String
    public let universalLinkDomains: [String]
    public let customURLSchemes: [String]
    public let debugLogging: Bool

    public init(
        appIdentifier: String,
        apiKey: String,
        licenseServerURL: URL,
        licenseValidationPath: String = "api/v1/license/validate",
        universalLinkDomains: [String] = [],
        customURLSchemes: [String] = [],
        debugLogging: Bool = false
    ) {
        self.appIdentifier = appIdentifier
        self.apiKey = apiKey
        self.licenseServerURL = licenseServerURL
        self.licenseValidationPath = licenseValidationPath
        self.universalLinkDomains = universalLinkDomains
        self.customURLSchemes = customURLSchemes
        self.debugLogging = debugLogging
    }
}
