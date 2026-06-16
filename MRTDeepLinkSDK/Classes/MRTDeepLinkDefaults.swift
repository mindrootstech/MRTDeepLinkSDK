import Foundation

public enum MRTDeepLinkDefaults {
    /// Default admin server — override only for staging/custom deployments.
    public static let licenseServerURL = URL(string: "https://glennis-pseudosyphilitic-maude.ngrok-free.dev")!
    public static let licenseValidationPath = "api/sdk/validate"
    public static let eventsPath = "api/sdk/events"
    public static let sdkKeyHeader = "X-SDK-Key"
    public static let authorizationHeader = "Authorization"
    /// New session starts after this many seconds in background (default 30 minutes).
    public static let sessionTimeout: TimeInterval = 30 * 60

    public static func authorizationValue(apiKey: String) -> String {
        "Bearer \(apiKey)"
    }
}
