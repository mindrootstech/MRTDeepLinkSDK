import Foundation

public enum MRTDeepLinkDefaults {
    /// Default admin server — override only for staging/custom deployments.
    public static let licenseServerURL = URL(string: "https://glennis-pseudosyphilitic-maude.ngrok-free.dev")!
    public static let licenseValidationPath = "api/sdk/validate"
    public static let eventsPath = "api/sdk/events"
    public static let sdkKeyHeader = "X-SDK-Key"
    public static let authorizationHeader = "Authorization"

    public static func authorizationValue(apiKey: String) -> String {
        "Bearer \(apiKey)"
    }
}
