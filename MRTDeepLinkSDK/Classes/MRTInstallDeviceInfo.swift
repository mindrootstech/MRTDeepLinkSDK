import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct MRTInstallRequestBody: Encodable, Sendable {
    let deviceId: String
    let platform: String
    let os: String
    let osVersion: String
    let appVersion: String
    let userAgent: String
    let language: String
}

enum MRTInstallDeviceInfo {
    private static let keychainService = "com.mrtdeeplink.keychain"
    private static let keychainAccount = "deviceId"
    private static let legacyDeviceIdKey = "com.mrtdeeplink.install.deviceId"

    static var platform: String { "ios" }

    static var osVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    /// Stable device ID stored in Keychain (migrates legacy UserDefaults value on first read).
    static func stableDeviceId() -> String {
        if let keychainId = MRTKeychainStore.read(service: keychainService, account: keychainAccount),
           !keychainId.isEmpty {
            return keychainId
        }

        if let legacyId = UserDefaults.standard.string(forKey: legacyDeviceIdKey),
           !legacyId.isEmpty {
            _ = MRTKeychainStore.save(service: keychainService, account: keychainAccount, value: legacyId)
            UserDefaults.standard.removeObject(forKey: legacyDeviceIdKey)
            return legacyId
        }

        let generated = UUID().uuidString.uppercased()
        _ = MRTKeychainStore.save(service: keychainService, account: keychainAccount, value: generated)
        return generated
    }

    static func makeRequestBody() -> MRTInstallRequestBody {
        #if canImport(UIKit)
        return MRTInstallRequestBody(
            deviceId: stableDeviceId(),
            platform: "ios",
            os: "iOS",
            osVersion: osVersion,
            appVersion: appVersion(),
            userAgent: userAgent(),
            language: languageCode()
        )
        #else
        return MRTInstallRequestBody(
            deviceId: stableDeviceId(),
            platform: "ios",
            os: "iOS",
            osVersion: osVersion,
            appVersion: "0.0.0",
            userAgent: "MRTDeepLinkSDK",
            language: Locale.current.identifier
        )
        #endif
    }

    #if canImport(UIKit)
    private static func appVersion() -> String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "\(short) (\(build))"
    }

    private static func userAgent() -> String {
        let systemVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        return "Mozilla/5.0 (iPhone; CPU iPhone OS \(systemVersion) like Mac OS X) MRTDeepLinkSDK"
    }

    private static func languageCode() -> String {
        Locale.preferredLanguages.first ?? Locale.current.identifier
    }
    #endif
}
