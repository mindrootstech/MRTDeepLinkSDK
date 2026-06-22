import Foundation

public enum MRTSmartLinkBuilder {
    /// Shareable web URL — opens the app when tapped if installed, otherwise redirects to the store.
    /// Example: https://deeplink.mindroots.com/product/42?id=abc
    public static func makeWebURL(
        path: String,
        queryItems: [URLQueryItem] = [],
        configuration: MRTSmartLinkConfiguration
    ) -> URL? {
        var normalizedPath = path
        if !normalizedPath.hasPrefix("/") {
            normalizedPath = "/\(normalizedPath)"
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = configuration.webDomain
        components.path = normalizedPath
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }

    /// Custom scheme URL — use when the app is already installed.
    public static func makeAppURL(
        path: String,
        queryItems: [URLQueryItem] = [],
        scheme: String
    ) -> URL? {
        var normalizedPath = path
        if normalizedPath.hasPrefix("/") {
            normalizedPath = String(normalizedPath.dropFirst())
        }

        var components = URLComponents()
        components.scheme = scheme
        components.path = "/\(normalizedPath)"
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }
}
