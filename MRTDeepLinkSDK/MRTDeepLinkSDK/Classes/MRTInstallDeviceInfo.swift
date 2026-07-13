import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum MRTInstallDeviceInfo {
    static var osVersion: String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    static func osVersionMajor() -> String {
        #if canImport(UIKit)
        return ProcessInfo.processInfo.operatingSystemVersion.majorVersion.description
        #else
        return osVersion.split(separator: ".").first.map(String.init) ?? osVersion
        #endif
    }

    static func matchLocale() -> String {
        if let preferred = Locale.preferredLanguages.first {
            return preferred.replacingOccurrences(of: "_", with: "-")
        }
        return Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    }

    /// Must match JS `bucketScreen(width, height)` on fp-probe.
    static func screenBucket() -> String {
        #if canImport(UIKit)
        let size: CGSize
        if Thread.isMainThread {
            size = UIScreen.main.bounds.size
        } else {
            size = DispatchQueue.main.sync { UIScreen.main.bounds.size }
        }
        let minSide = min(size.width, size.height)
        let maxSide = max(size.width, size.height)
        if minSide >= 600 { return "tablet" }
        if maxSide >= 800 { return "large" }
        if maxSide >= 700 { return "medium" }
        return "small"
        #else
        return "medium"
        #endif
    }

    static func mapContentSizeCategory() -> String? {
        #if canImport(UIKit)
        let category: UIContentSizeCategory
        if Thread.isMainThread {
            category = UIApplication.shared.preferredContentSizeCategory
        } else {
            category = DispatchQueue.main.sync { UIApplication.shared.preferredContentSizeCategory }
        }
        let map: [UIContentSizeCategory: String] = [
            .extraSmall: "XS", .small: "S", .medium: "M", .large: "L",
            .extraLarge: "XL", .extraExtraLarge: "XXL",
            .extraExtraExtraLarge: "XXXL",
            .accessibilityMedium: "AX-M", .accessibilityLarge: "AX-L",
            .accessibilityExtraLarge: "AX-XL",
            .accessibilityExtraExtraLarge: "AX-XXL",
            .accessibilityExtraExtraExtraLarge: "AX-XXXL"
        ]
        return map[category]
        #else
        return nil
        #endif
    }

    static func colorScheme() -> String {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle
        if Thread.isMainThread {
            style = UITraitCollection.current.userInterfaceStyle
        } else {
            style = DispatchQueue.main.sync { UITraitCollection.current.userInterfaceStyle }
        }
        return style == .dark ? "dark" : "light"
        #else
        return "light"
        #endif
    }

    static func batteryState() -> (level: Double?, charging: Bool?) {
        #if canImport(UIKit)
        let readState: () -> (Float, UIDevice.BatteryState) = {
            UIDevice.current.isBatteryMonitoringEnabled = true
            return (UIDevice.current.batteryLevel, UIDevice.current.batteryState)
        }
        let level: Float
        let state: UIDevice.BatteryState
        if Thread.isMainThread {
            (level, state) = readState()
        } else {
            (level, state) = DispatchQueue.main.sync { readState() }
        }

        let normalizedLevel = level >= 0 ? Double(level) : nil
        let charging: Bool?
        switch state {
        case .charging, .full: charging = true
        case .unplugged: charging = false
        case .unknown: charging = nil
        @unknown default: charging = nil
        }
        return (normalizedLevel, charging)
        #else
        return (nil, nil)
        #endif
    }
}
