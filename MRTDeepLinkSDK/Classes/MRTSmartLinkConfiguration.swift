import Foundation

public struct MRTSmartLinkConfiguration: Sendable {
    public let webDomain: String
    public let customURLScheme: String
    public let iOSAppStoreURL: URL
    public let androidPlayStoreURL: URL
    public let androidPackageName: String

    public init(
        webDomain: String,
        customURLScheme: String,
        iOSAppStoreURL: URL,
        androidPlayStoreURL: URL,
        androidPackageName: String
    ) {
        self.webDomain = webDomain
        self.customURLScheme = customURLScheme
        self.iOSAppStoreURL = iOSAppStoreURL
        self.androidPlayStoreURL = androidPlayStoreURL
        self.androidPackageName = androidPackageName
    }
}
