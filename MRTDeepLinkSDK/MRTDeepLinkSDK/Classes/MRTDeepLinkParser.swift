import Foundation

enum MRTDeepLinkParser {
    static func parse(url: URL, configuration: MRTDeepLinkConfiguration) -> MRTDeepLinkPayload? {
        guard let source = detectSource(for: url, configuration: configuration) else {
            return nil
        }

        let path = normalizedPath(from: url)
        let pathComponents = path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        return MRTDeepLinkPayload(
            url: url,
            path: path,
            pathComponents: pathComponents,
            queryParameters: queryParameters(from: url),
            source: source
        )
    }

    private static func detectSource(for url: URL, configuration: MRTDeepLinkConfiguration) -> MRTDeepLinkSource? {
        let scheme = url.scheme?.lowercased() ?? ""

        if configuration.customURLSchemes.map({ $0.lowercased() }).contains(scheme) {
            return .customScheme
        }

        if scheme == "https" || scheme == "http" {
            // No domain configured → accept any https host.
            if configuration.universalLinkDomains.isEmpty {
                return .universalLink
            }
            if let host = url.host?.lowercased() {
                let allowed = configuration.universalLinkDomains.map { $0.lowercased() }
                if allowed.contains(host) {
                    return .universalLink
                }
                // Also accept common `www.` / without mismatch both ways.
                let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
                if allowed.contains(bare) || allowed.contains("www.\(bare)") {
                    return .universalLink
                }
            }
        }

        if configuration.customURLSchemes.isEmpty, configuration.universalLinkDomains.isEmpty {
            return url.host != nil ? .universalLink : .customScheme
        }

        return nil
    }

    private static func normalizedPath(from url: URL) -> String {
        var segments: [String] = []

        if let host = url.host, !host.isEmpty {
            segments.append(host)
        }

        segments.append(
            contentsOf: url.path
                .split(separator: "/")
                .map(String.init)
                .filter { !$0.isEmpty }
        )

        if segments.isEmpty {
            return "/"
        }
        return "/" + segments.joined(separator: "/")
    }

    private static func queryParameters(from url: URL) -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return [:]
        }

        var parameters: [String: String] = [:]
        for item in items {
            parameters[item.name] = item.value ?? ""
        }
        return parameters
    }

    /// Parses click session id from a launch / universal link URL query.
    /// Accepts `session`, `clickSessionId`, and `click_session_id`.
    static func parseClickSessionId(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems else {
            return nil
        }

        for key in ["session", "clickSessionId", "click_session_id"] {
            if let value = items.first(where: { $0.name == key })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
