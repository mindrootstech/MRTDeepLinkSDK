import Foundation

public enum MRTDeepLinkLicenseStatus: Sendable, Equatable {
    case idle
    case validating
    case valid
    case invalid(message: String)
}

private struct MRTDeepLinkLicenseResponse: Decodable, Sendable {
    let valid: Bool?
    let success: Bool?
    let message: String?
    let error: String?
    let appIdentifier: String?
    let universalLinkDomains: [String]?
    let customURLSchemes: [String]?
    let config: NestedConfig?

    struct NestedConfig: Decodable, Sendable {
        let appIdentifier: String
        let universalLinkDomains: [String]?
        let customURLSchemes: [String]?
    }

    var isValid: Bool {
        valid == true || success == true
    }

    var errorMessage: String? {
        if let message, !message.isEmpty { return message }
        if let error, !error.isEmpty { return error }
        return nil
    }

    var remoteConfig: MRTDeepLinkRemoteConfig? {
        if let config {
            return MRTDeepLinkRemoteConfig(
                appIdentifier: config.appIdentifier,
                universalLinkDomains: config.universalLinkDomains ?? [],
                customURLSchemes: config.customURLSchemes ?? []
            )
        }

        guard let appIdentifier else { return nil }
        return MRTDeepLinkRemoteConfig(
            appIdentifier: appIdentifier,
            universalLinkDomains: universalLinkDomains ?? [],
            customURLSchemes: customURLSchemes ?? []
        )
    }
}

enum MRTDeepLinkLicenseValidationResult: Sendable {
    case success(MRTDeepLinkRemoteConfig)
    case failure(String)
}

enum MRTDeepLinkLicenseValidator {
    static func makeValidationURL(
        apiKey: String,
        bundleId: String,
        serverURL: URL,
        validationPath: String
    ) -> URL? {
        validationURL(
            serverURL: serverURL,
            validationPath: validationPath,
            apiKey: apiKey,
            bundleId: bundleId
        )
    }

    static func validate(
        apiKey: String,
        bundleId: String,
        serverURL: URL,
        validationPath: String,
        debugLogging: Bool = false
    ) async -> MRTDeepLinkLicenseValidationResult {
        guard let url = validationURL(
            serverURL: serverURL,
            validationPath: validationPath,
            apiKey: apiKey,
            bundleId: bundleId
        ) else {
            return .failure("Invalid license server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        MRTSDKRequestAuth.apply(apiKey: apiKey, to: &request)
        MRTSDKRequestAuth.logHeaders(for: request, label: "License API", debugLogging: debugLogging)

        let result = await MRTURLSessionRetry.data(for: request)
        switch result {
        case .success(let httpResult):
            let rawBody = String(data: httpResult.data, encoding: .utf8) ?? ""
            let license = try? JSONDecoder().decode(MRTDeepLinkLicenseResponse.self, from: httpResult.data)

            MRTSDKLogger.debug("License API status: \(httpResult.statusCode)", enabled: debugLogging)
            if debugLogging, !rawBody.isEmpty {
                MRTSDKLogger.debug("License API response: \(rawBody)", enabled: true)
            }

            if license?.isValid == true {
                if let remoteConfig = license?.remoteConfig {
                    return .success(remoteConfig)
                }

                MRTSDKLogger.debug("License valid (boolean response) — using bundle config", enabled: debugLogging)
                return .success(
                    MRTDeepLinkRemoteConfig(
                        appIdentifier: bundleId,
                        universalLinkDomains: [],
                        customURLSchemes: []
                    )
                )
            }

            if let message = license?.errorMessage {
                MRTSDKLogger.debug("License API error: \(message)", enabled: debugLogging)
                return .failure(message)
            }

            if !rawBody.isEmpty {
                let fallback = "License validation failed (\(httpResult.statusCode)): \(rawBody)"
                MRTSDKLogger.debug("License API error: \(fallback)", enabled: debugLogging)
                return .failure(fallback)
            }

            let fallback = "License validation failed (\(httpResult.statusCode))"
            MRTSDKLogger.debug("License API error: \(fallback)", enabled: debugLogging)
            return .failure(fallback)

        case .failure(let error):
            switch error {
            case .requestFailed(let message):
                MRTSDKLogger.debug("License API error: \(message)", enabled: debugLogging)
                return .failure(message)
            }
        }
    }

    private static func validationURL(
        serverURL: URL,
        validationPath: String,
        apiKey: String,
        bundleId: String
    ) -> URL? {
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
        let normalizedPath = validationPath.hasPrefix("/") ? validationPath : "/\(validationPath)"
        let basePath = components?.path ?? ""

        if basePath.isEmpty || basePath == "/" {
            components?.path = normalizedPath
        } else {
            components?.path = basePath + normalizedPath
        }

        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "bundleId", value: bundleId)
        ]

        return components?.url
    }
}
