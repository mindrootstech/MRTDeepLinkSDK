import Foundation

public enum MRTDeepLinkDefaults {
    /// Default admin server — override only for staging/custom deployments.
    public static let licenseServerURL = URL(string: "https://glennis-pseudosyphilitic-maude.ngrok-free.dev")!
    public static let licenseValidationPath = "api/sdk/validate"
    public static let eventsPath = "api/sdk/events"
    public static let installPath = "api/sdk/install"
    public static let uniqueInstallPath = "api/sdk/unique-install"
    public static let sdkKeyHeader = "X-SDK-Key"
    public static let authorizationHeader = "Authorization"
    /// New session starts after this many seconds in background (default 30 minutes).
    public static let sessionTimeout: TimeInterval = 30 * 60
    /// Maximum attempts for retryable SDK network requests.
    public static let apiMaxRetryAttempts = 3
    /// Initial delay before the second retry attempt.
    public static let apiRetryInitialDelay: TimeInterval = 0.5
    /// Maximum number of analytics events stored offline.
    public static let offlineEventQueueLimit = 100

    public static func authorizationValue(apiKey: String) -> String {
        "Bearer \(apiKey)"
    }
}
