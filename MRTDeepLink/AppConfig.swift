import Foundation
import CliqIt

enum AppConfig {
    static let sdkAPIKey = "pk_live_YOUR_API_KEY"
    /// Match / SDK API host (must match SDK default)
    static let serverURL = "https://api.theblockyapp.com"
    /// SmartLink host from admin panel — used only for demo sample links / UI.
    static let universalLinkDomain = "theblockyapp.com"
    static let sampleSmartLinkURL = "https://theblockyapp.com/r/85eJtf"
    static let customURLScheme = "mrtdeeplink"
    static let defaultClickSessionId = "c8474ac0-1f13-4890-95ac-bbe5029f2f15"

    static var smartLinkConfiguration: CliqItSmartLinkConfiguration {
        CliqItSmartLinkConfiguration(
            webDomain: universalLinkDomain,
            customURLScheme: customURLScheme,
            iOSAppStoreURL: URL(string: "https://apps.apple.com/app/id0000000000")!
        )
    }

    static var customSchemeTestURL: URL? {
        CliqItSmartLinkBuilder.makeAppURL(
            path: "/welcome",
            scheme: customURLScheme
        )
    }
}
