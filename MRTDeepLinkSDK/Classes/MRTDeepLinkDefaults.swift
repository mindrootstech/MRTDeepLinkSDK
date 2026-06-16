import Foundation

public enum MRTDeepLinkDefaults {
    /// Default admin server — override only for staging/custom deployments.
    public static let licenseServerURL = URL(string: "https://glennis-pseudosyphilitic-maude.ngrok-free.dev")!
    public static let licenseValidationPath = "api/sdk/validate"
    public static let eventsPath = "api/events"
}
