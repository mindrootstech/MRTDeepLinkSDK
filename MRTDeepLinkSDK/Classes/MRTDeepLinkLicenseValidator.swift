import Foundation

public enum MRTDeepLinkLicenseStatus: Sendable, Equatable {
    case idle
    case validating
    case valid
    case invalid(message: String)
}

private struct MRTDeepLinkLicenseResponse: Decodable, Sendable {
    let valid: Bool
    let message: String?
    let appIdentifier: String?
    let universalLinkDomains: [String]?
    let customURLSchemes: [String]?
    let config: NestedConfig?

    struct NestedConfig: Decodable, Sendable {
        let appIdentifier: String
        let universalLinkDomains: [String]?
        let customURLSchemes: [String]?
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
    static func validate(
        apiKey: String,
        bundleId: String,
        serverURL: URL,
        validationPath: String
    ) async -> MRTDeepLinkLicenseValidationResult {
        guard let url = validationURL(serverURL: serverURL, validationPath: validationPath) else {
            return .failure("Invalid license server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-MRT-API-Key")
        request.httpBody = try? JSONEncoder().encode(["bundleId": bundleId])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid server response")
            }

            let license = try? JSONDecoder().decode(MRTDeepLinkLicenseResponse.self, from: data)

            if (200...299).contains(httpResponse.statusCode),
               license?.valid == true,
               let remoteConfig = license?.remoteConfig {
                return .success(remoteConfig)
            }

            if let message = license?.message, !message.isEmpty {
                return .failure(message)
            }

            return .failure("License validation failed (\(httpResponse.statusCode))")
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private static func validationURL(serverURL: URL, validationPath: String) -> URL? {
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
        let normalizedPath = validationPath.hasPrefix("/") ? validationPath : "/\(validationPath)"
        let basePath = components?.path ?? ""

        if basePath.isEmpty || basePath == "/" {
            components?.path = normalizedPath
        } else {
            components?.path = basePath + normalizedPath
        }

        return components?.url
    }
}
