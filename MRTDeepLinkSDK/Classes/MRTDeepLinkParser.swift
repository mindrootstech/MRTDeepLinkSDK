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
            if configuration.universalLinkDomains.isEmpty {
                return .universalLink
            }
            if let host = url.host?.lowercased(),
               configuration.universalLinkDomains.map({ $0.lowercased() }).contains(host) {
                return .universalLink
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
}
