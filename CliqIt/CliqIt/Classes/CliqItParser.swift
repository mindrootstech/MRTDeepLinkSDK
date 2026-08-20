import Foundation

enum CliqItParser {
    static func parse(url: URL, configuration: CliqItConfiguration) -> CliqItPayload? {
        guard let source = detectSource(for: url, configuration: configuration) else {
            return nil
        }

        let path = normalizedPath(from: url)
        let pathComponents = path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        return CliqItPayload(
            url: url,
            path: path,
            pathComponents: pathComponents,
            queryParameters: queryParameters(from: url),
            source: source
        )
    }

    private static func detectSource(for url: URL, configuration: CliqItConfiguration) -> CliqItSource? {
        let scheme = url.scheme?.lowercased() ?? ""

        if configuration.customURLSchemes.map({ $0.lowercased() }).contains(scheme) {
            return .customScheme
        }

        // No scheme configured → only accept schemes registered by this app (Info.plist).
        if configuration.customURLSchemes.isEmpty, registeredCustomSchemes().contains(scheme) {
            return .customScheme
        }

        if scheme == "https" || scheme == "http" {
            guard let host = url.host?.lowercased(), isAllowedUniversalLinkHost(host, configuration: configuration) else {
                return nil
            }
            return .universalLink
        }

        return nil
    }

    /// Exact / www-normalized match against configured domains, else default `*.theblockyapp.com`.
    static func isAllowedUniversalLinkHost(_ host: String, configuration: CliqItConfiguration) -> Bool {
        let allowed = configuration.universalLinkDomains.map { $0.lowercased() }
        if !allowed.isEmpty {
            if allowed.contains(host) { return true }
            let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            return allowed.contains(bare) || allowed.contains("www.\(bare)")
        }
        let root = CliqItDefaults.allowedLinkDomain.lowercased()
        return host == root || host.hasSuffix("." + root)
    }

    private static func registeredCustomSchemes() -> Set<String> {
        guard let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return []
        }
        var schemes = Set<String>()
        for type in types {
            guard let list = type["CFBundleURLSchemes"] as? [String] else { continue }
            for scheme in list {
                let trimmed = scheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !trimmed.isEmpty { schemes.insert(trimmed) }
            }
        }
        return schemes
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

    /// Last path segment of the link — used as `{slug}` for `/api/v1/sdk/link/{slug}`.
    /// e.g. `https://host/r/85eJtf` → `85eJtf`; `myapp://85eJtf` → `85eJtf`.
    static func slug(from url: URL) -> String? {
        let pathParts = url.path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
        if let last = pathParts.last {
            return last
        }
        if let host = url.host?.trimmingCharacters(in: .whitespacesAndNewlines), !host.isEmpty {
            return host
        }
        return nil
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
