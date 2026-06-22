import Foundation

struct MRTAnalyticsConfiguration: Sendable {
    let apiKey: String
    let serverURL: URL
    let eventsPath: String
    let debugLogging: Bool
    let bundleId: String

    init(
        apiKey: String,
        debugLogging: Bool = false,
        serverURL: URL = MRTDeepLinkDefaults.licenseServerURL,
        eventsPath: String = MRTDeepLinkDefaults.eventsPath,
        bundleId: String = Bundle.main.bundleIdentifier ?? ""
    ) {
        self.apiKey = apiKey
        self.serverURL = serverURL
        self.eventsPath = eventsPath
        self.debugLogging = debugLogging
        self.bundleId = bundleId
    }
}
