import Foundation

public struct MRTDeepLinkConfiguration: Sendable {
    public let appIdentifier: String
    public let universalLinkDomains: [String]
    public let customURLSchemes: [String]
    public let debugLogging: Bool

    public init(
        appIdentifier: String,
        universalLinkDomains: [String] = [],
        customURLSchemes: [String] = [],
        debugLogging: Bool = false
    ) {
        self.appIdentifier = appIdentifier
        self.universalLinkDomains = universalLinkDomains
        self.customURLSchemes = customURLSchemes
        self.debugLogging = debugLogging
    }
}
