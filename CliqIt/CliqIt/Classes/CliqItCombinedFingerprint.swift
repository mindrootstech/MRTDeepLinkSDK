import CryptoKit
import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Stable digest from native + WebView signals.
/// WebView-only hashes are often identical across iPhones; locale / a11y / screen are not.
public struct CliqItCombinedFingerprint: Sendable, Equatable {
    public let digest: String
    public let parts: [String: String]

    public var shortDigest: String {
        String(digest.prefix(16))
    }
}

enum CliqItCombinedFingerprintBuilder {
    static func build(web: CliqItWebFingerprint?) -> CliqItCombinedFingerprint {
        #if canImport(UIKit)
        let bold = UIAccessibility.isBoldTextEnabled
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let increaseContrast = UIAccessibility.isDarkerSystemColorsEnabled
        let screen: String = {
            let size: CGSize
            let scale: CGFloat
            if Thread.isMainThread {
                size = UIScreen.main.bounds.size
                scale = UIScreen.main.scale
            } else {
                (size, scale) = DispatchQueue.main.sync {
                    (UIScreen.main.bounds.size, UIScreen.main.scale)
                }
            }
            return "\(Int(size.width))x\(Int(size.height))@\(scale)"
        }()
        #else
        let bold = false
        let reduceMotion = false
        let increaseContrast = false
        let screen = "unknown"
        #endif

        var parts: [String: String] = [
            "osVersion": CliqItInstallDeviceInfo.osVersion,
            "deviceName": CliqItInstallDeviceInfo.deviceName(),
            "locale": CliqItInstallDeviceInfo.matchLocale(),
            "languages": Locale.preferredLanguages.joined(separator: ","),
            "timezone": TimeZone.current.identifier,
            "screen": screen,
            "screenBucket": CliqItInstallDeviceInfo.screenBucket(),
            "pixelRatioBucket": CliqItInstallDeviceInfo.devicePixelRatioBucket(),
            "colorScheme": CliqItInstallDeviceInfo.colorScheme(),
            "hourCycle": CliqItInstallDeviceInfo.hourCycle(),
            "hardwareConcurrency": String(ProcessInfo.processInfo.processorCount),
            "boldText": bold ? "1" : "0",
            "reduceMotion": reduceMotion ? "1" : "0",
            "increaseContrast": increaseContrast ? "1" : "0"
        ]

        if let v = CliqItInstallDeviceInfo.currencyCode() { parts["currency"] = v }
        if let v = CliqItInstallDeviceInfo.regionCode() { parts["regionCode"] = v }
        if let v = CliqItInstallDeviceInfo.mapContentSizeCategory() { parts["dynamicTypeSize"] = v }

        if let web {
            if let v = web.canvasHash { parts["canvasHash"] = v }
            if let v = web.webglHash { parts["webglHash"] = v }
            if let v = web.webglVendor { parts["webglVendor"] = v }
            if let v = web.webglRenderer { parts["webglRenderer"] = v }
            if let v = web.audioHash { parts["audioHash"] = v }
            if let v = web.clockSkewMs { parts["clockSkewMs"] = String(Int(v.rounded())) }
            if let v = web.fontHash { parts["fontHash"] = v }
            if let v = web.jsTimezone { parts["jsTimezone"] = v }
            if let v = web.jsLanguages { parts["jsLanguages"] = v }
            if let v = web.jsScreen { parts["jsScreen"] = v }
        }

        let canonical = parts.keys.sorted().map { "\($0)=\(parts[$0]!)" }.joined(separator: "|")
        let digest = SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        return CliqItCombinedFingerprint(digest: digest, parts: parts)
    }
}
