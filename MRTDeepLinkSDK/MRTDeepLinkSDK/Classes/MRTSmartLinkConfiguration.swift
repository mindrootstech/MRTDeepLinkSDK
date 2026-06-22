import Foundation

public struct MRTSmartLinkConfiguration: Sendable {
    public let webDomain: String
    public let customURLScheme: String
    public let iOSAppStoreURL: URL

    public init(
        webDomain: String,
        customURLScheme: String,
        iOSAppStoreURL: URL
    ) {
        self.webDomain = webDomain
        self.customURLScheme = customURLScheme
        self.iOSAppStoreURL = iOSAppStoreURL
    }
}
