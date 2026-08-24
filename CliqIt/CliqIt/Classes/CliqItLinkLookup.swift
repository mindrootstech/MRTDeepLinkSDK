import Foundation

/// Typed keys for direct-link lookup `data` — use `details[.slug]` instead of stringly access.
public enum CliqItLinkField: String, CaseIterable, Sendable {
    case destination
    case iosDestination
    case androidDestination
    case ogTitle
    case ogDescription
    case ogImage
    case ogUrl
    case slug
    case webFallback
    case showInterstitial
    case isDeepLink
    case appleTeamId
    case iosBundleId
    case androidPackageName
    /// Resolved navigation path: `iosDestination` ?? `destination`.
    case resolvedPath
}

/// Switch-friendly direct-link lookup result.
public enum CliqItLinkLookupOutcome: Sendable, Equatable {
    case resolved(CliqItLinkDetails)
    case failed(CliqItDeferredMatchError)

    public var details: CliqItLinkDetails? {
        if case .resolved(let details) = self { return details }
        return nil
    }

    public var resolvedPath: String? { details?.resolvedPath }
}

public struct CliqItLinkDetails: Decodable, Sendable, Equatable {
    public let destination: String?
    public let iosDestination: String?
    public let androidDestination: String?
    public let ogTitle: String?
    public let ogDescription: String?
    public let ogImage: String?
    public let ogUrl: String?
    public let slug: String?
    public let webFallback: String?
    public let showInterstitial: Bool?
    public let isDeepLink: Bool?
    public let appleTeamId: String?
    public let iosBundleId: String?
    public let androidPackageName: String?

    /// iOS navigation path: `iosDestination` if set, else `destination`.
    public var resolvedPath: String? {
        if let ios = Self.normalizedPath(iosDestination) { return ios }
        return Self.normalizedPath(destination)
    }

    public subscript(_ field: CliqItLinkField) -> String? {
        switch field {
        case .destination: return destination
        case .iosDestination: return iosDestination
        case .androidDestination: return androidDestination
        case .ogTitle: return ogTitle
        case .ogDescription: return ogDescription
        case .ogImage: return ogImage
        case .ogUrl: return ogUrl
        case .slug: return slug
        case .webFallback: return webFallback
        case .showInterstitial: return showInterstitial.map { $0 ? "true" : "false" }
        case .isDeepLink: return isDeepLink.map { $0 ? "true" : "false" }
        case .appleTeamId: return appleTeamId
        case .iosBundleId: return iosBundleId
        case .androidPackageName: return androidPackageName
        case .resolvedPath: return resolvedPath
        }
    }

    private static func normalizedPath(_ raw: String?) -> String? {
        guard var value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.lowercased() == "null" { return nil }
        if !value.hasPrefix("/") { value = "/\(value)" }
        return value
    }
}

public struct CliqItLinkLookupResponse: Decodable, Sendable, Equatable {
    public let status: Bool
    public let message: String?
    public let data: CliqItLinkDetails?

    public var outcome: CliqItLinkLookupOutcome {
        if status, let data {
            return .resolved(data)
        }
        return .failed(.message(message ?? "Link lookup failed"))
    }

    public subscript(_ field: CliqItLinkField) -> String? {
        data?[field]
    }
}

public typealias CliqItDirectLinkLookupHandler = (Result<CliqItLinkDetails, CliqItDeferredMatchError>) -> Void

enum CliqItLinkLookupClient {
    static func fetch(
        slug: String,
        configuration: CliqItConfiguration
    ) async -> Result<CliqItLinkDetails, CliqItDeferredMatchError> {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(.message("Empty link slug"))
        }

        guard var url = URL(string: configuration.serverURL.absoluteString) else {
            return .failure(.message("Invalid server URL"))
        }
        for part in CliqItDefaults.linkLookupPath
            .split(separator: "/")
            .map(String.init)
            .filter({ !$0.isEmpty })
        {
            url.appendPathComponent(part)
        }
        url.appendPathComponent(trimmed)
        CliqItSDKIdentity.appendQueryIdentity(to: &url)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        CliqItRequestAuth.apply(apiKey: configuration.apiKey, to: &request)
        CliqItRequestAuth.logRequest(
            name: "linkLookup",
            request: request,
            debugLogging: configuration.debugLogging
        )

        switch await CliqItURLSessionRetry.data(for: request) {
        case .failure(let error):
            switch error {
            case .requestFailed(let message):
                return .failure(.message(message))
            }
        case .success(let http):
            let body = String(data: http.data, encoding: .utf8) ?? ""
            CliqItRequestAuth.logResponse(
                name: "linkLookup",
                statusCode: http.statusCode,
                body: body,
                debugLogging: configuration.debugLogging
            )

            do {
                let decoded = try JSONDecoder().decode(CliqItLinkLookupResponse.self, from: http.data)
                switch decoded.outcome {
                case .resolved(let details):
                    return .success(details)
                case .failed(let error):
                    return .failure(error)
                }
            } catch {
                return .failure(.message("Invalid link lookup response: \(error.localizedDescription)"))
            }
        }
    }

    static func makeResolvedPayload(
        details: CliqItLinkDetails,
        originalURL: URL,
        source: CliqItSource,
        queryParameters: [String: String]
    ) -> CliqItPayload? {
        guard let path = details[.resolvedPath] else { return nil }
        let pathComponents = path
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        return CliqItPayload(
            url: originalURL,
            path: path,
            pathComponents: pathComponents,
            queryParameters: queryParameters,
            source: source,
            isDeferred: false,
            status: .opened,
            slug: details[.slug],
            destinationPath: path
        )
    }
}
