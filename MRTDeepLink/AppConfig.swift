import Foundation
import MRTDeepLinkSDK

enum AppConfig {
    static let sdkAPIKey = "dlh_sdk_bf5a418781645414bb0cb0dbbe4eb981"
    /// Match / SDK API host
    static let serverURL = "https://api.digitalplayground.quest"
    /// Must match Associated Domains (`applinks:…`) and the SmartLink host users tap.
    static let universalLinkDomain = "app.digitalplayground.quest"
    static let sampleSmartLinkURL = "https://app.digitalplayground.quest/r/85eJtf"
    static let customURLScheme = "mrtdeeplink"
    static let defaultClickSessionId = "c8474ac0-1f13-4890-95ac-bbe5029f2f15"

    static var smartLinkConfiguration: MRTSmartLinkConfiguration {
        MRTSmartLinkConfiguration(
            webDomain: universalLinkDomain,
            customURLScheme: customURLScheme,
            iOSAppStoreURL: URL(string: "https://apps.apple.com/app/id0000000000")!
        )
    }

    static var customSchemeTestURL: URL? {
        MRTSmartLinkBuilder.makeAppURL(
            path: "/welcome",
            scheme: customURLScheme
        )
    }
}
