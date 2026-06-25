import Foundation

struct MRTInstallAttribution: Decodable, Sendable {
    let url: String?
    let destinationUrl: String?
    let deepLink: String?
    let path: String?
    let shortCode: String?
    let slug: String?
    let linkId: String?
    let queryParameters: [String: String]?
    let metadata: [String: String]?
    let data: [String: String]?
}

struct MRTInstallResult: Sendable {
    let installId: String?
    let isAttributed: Bool
    let matchConfidence: Double?
    let confidenceLevel: String?
    let attribution: MRTInstallAttribution?
}

enum MRTInstallError: Error, Sendable {
    case message(String)
}

enum MRTInstallClient {
    static func reportInstall(
        configuration: MRTDeepLinkConfiguration,
        installPath: String = MRTDeepLinkDefaults.installPath,
        debugLogging: Bool = false
    ) async -> Result<MRTInstallResult, MRTInstallError> {
        guard let url = installURL(
            serverURL: configuration.licenseServerURL,
            installPath: installPath,
            bundleId: configuration.appIdentifier
        ) else {
            return .failure(.message("Invalid install server URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        MRTSDKRequestAuth.apply(apiKey: configuration.apiKey, to: &request)

        let body = MRTInstallDeviceInfo.makeRequestBody()

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return .failure(.message("Failed to encode install payload: \(error.localizedDescription)"))
        }

        if debugLogging {
            MRTSDKRequestAuth.logHeaders(for: request, label: "Install API", debugLogging: true)
            if let json = String(data: request.httpBody ?? Data(), encoding: .utf8) {
                MRTSDKLogger.debug("Install API body: \(json)", enabled: true)
            }
        }

        let result = await MRTURLSessionRetry.data(for: request)
        switch result {
        case .success(let httpResult):
            let rawBody = String(data: httpResult.data, encoding: .utf8) ?? ""

            if debugLogging {
                MRTSDKLogger.debug("Install API status: \(httpResult.statusCode)", enabled: true)
                if !rawBody.isEmpty {
                    MRTSDKLogger.debug("Install API response: \(rawBody)", enabled: true)
                }
            }

            do {
                let decoded = try JSONDecoder().decode(MRTInstallAPIResponse.self, from: httpResult.data)
                guard let payload = decoded.data else {
                    return .failure(.message("Install response missing data"))
                }

                return .success(
                    MRTInstallResult(
                        installId: payload.installId,
                        isAttributed: payload.isAttributed == true,
                        matchConfidence: payload.matchConfidence,
                        confidenceLevel: payload.confidenceLevel,
                        attribution: payload.attribution
                    )
                )
            } catch {
                return .failure(.message("Failed to decode install response: \(error.localizedDescription)"))
            }

        case .failure(let error):
            switch error {
            case .requestFailed(let message):
                return .failure(.message(message))
            }
        }
    }

    static func makeDeferredPayload(
        attribution: MRTInstallAttribution,
        configuration: MRTDeepLinkConfiguration
    ) -> MRTDeepLinkPayload? {
        let candidateURLs = [
            attribution.url,
            attribution.destinationUrl,
            attribution.deepLink,
            buildURL(fromPath: attribution.path, configuration: configuration),
            buildURL(fromPath: attribution.slug.map { "/\($0)" }, configuration: configuration),
            buildURL(fromPath: attribution.shortCode.map { "/\($0)" }, configuration: configuration)
        ]

        for candidate in candidateURLs.compactMap({ $0 }) {
            guard let url = URL(string: candidate),
                  let payload = MRTDeepLinkParser.parse(url: url, configuration: configuration) else {
                continue
            }

            return deferredPayload(from: payload, extraQuery: attribution.queryParameters ?? attribution.metadata ?? attribution.data)
        }

        return nil
    }

    private static func buildURL(fromPath path: String?, configuration: MRTDeepLinkConfiguration) -> String? {
        guard let path, !path.isEmpty else { return nil }

        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let domain = configuration.universalLinkDomains.first else {
            return "https://\(configuration.licenseServerURL.host ?? "localhost")\(normalizedPath)"
        }

        return "https://\(domain)\(normalizedPath)"
    }

    private static func deferredPayload(
        from payload: MRTDeepLinkPayload,
        extraQuery: [String: String]?
    ) -> MRTDeepLinkPayload {
        guard let extraQuery, !extraQuery.isEmpty else {
            return MRTDeepLinkPayload(
                url: payload.url,
                path: payload.path,
                pathComponents: payload.pathComponents,
                queryParameters: payload.queryParameters,
                source: .deferred,
                receivedAt: payload.receivedAt,
                isDeferred: true
            )
        }

        var mergedQuery = payload.queryParameters
        for (key, value) in extraQuery where mergedQuery[key] == nil {
            mergedQuery[key] = value
        }

        return MRTDeepLinkPayload(
            url: payload.url,
            path: payload.path,
            pathComponents: payload.pathComponents,
            queryParameters: mergedQuery,
            source: .deferred,
            receivedAt: payload.receivedAt,
            isDeferred: true
        )
    }

    private static func installURL(
        serverURL: URL,
        installPath: String,
        bundleId: String
    ) -> URL? {
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
        let normalizedPath = installPath.hasPrefix("/") ? installPath : "/\(installPath)"
        let basePath = components?.path ?? ""

        if basePath.isEmpty || basePath == "/" {
            components?.path = normalizedPath
        } else {
            components?.path = basePath + normalizedPath
        }

        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleId)
        ]

        return components?.url
    }
}

private struct MRTInstallAPIResponse: Decodable {
    let success: Bool?
    let data: MRTInstallAPIData?
}

private struct MRTInstallAPIData: Decodable {
    let installId: String?
    let isAttributed: Bool?
    let matchConfidence: Double?
    let confidenceLevel: String?
    let attribution: MRTInstallAttribution?
}
