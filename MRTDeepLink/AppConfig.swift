import Foundation
import MRTDeepLinkSDK

enum AppConfig {
    static let appApiURL = "https://fakestoreapi.com"
    static let sdkAPIKey = "dlh_sdk_bf5a418781645414bb0cb0dbbe4eb981"
    static let serverURL = "https://apismartlink.digitalplayground.quest"
    static let universalLinkDomain = "apismartlink.digitalplayground.quest"
    static let sampleSmartLinkURL = "https://apismartlink.digitalplayground.quest/r/85eJtf"
    static let customURLScheme = "mrtdeeplink"
    static let sampleProductID = 1
    static let defaultClickSessionId = "c8474ac0-1f13-4890-95ac-bbe5029f2f15"

    static var smartLinkConfiguration: MRTSmartLinkConfiguration {
        MRTSmartLinkConfiguration(
            webDomain: universalLinkDomain,
            customURLScheme: customURLScheme,
            iOSAppStoreURL: URL(string: "https://apps.apple.com/app/id0000000000")!
        )
    }

    static func productDeepLinkPath(productID: Int) -> String {
        "/product/\(productID)"
    }

    static var customSchemeTestURL: URL? {
        MRTSmartLinkBuilder.makeAppURL(
            path: productDeepLinkPath(productID: sampleProductID),
            scheme: customURLScheme
        )
    }

    static func productShareURL(productID: Int) -> URL? {
        MRTSmartLinkBuilder.makeWebURL(
            path: productDeepLinkPath(productID: productID),
            configuration: smartLinkConfiguration
        )
    }
}
