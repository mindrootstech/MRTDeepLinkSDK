import Foundation

public struct CliqItSmartLinkConfiguration: Sendable {
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
