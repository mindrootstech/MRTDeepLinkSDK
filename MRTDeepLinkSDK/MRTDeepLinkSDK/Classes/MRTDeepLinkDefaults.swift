import Foundation

public enum MRTDeepLinkDefaults {
    public static let licenseServerURL = URL(string: "https://apismartlink.digitalplayground.quest")!
    public static let deferredMatchPath = "api/deferred/app/match"
    public static let sdkKeyHeader = "X-SDK-Key"
    public static let authorizationHeader = "Authorization"
    public static let apiMaxRetryAttempts = 3
    public static let apiRetryInitialDelay: TimeInterval = 0.5

    public static func authorizationValue(apiKey: String) -> String {
        "Bearer \(apiKey)"
    }
}
