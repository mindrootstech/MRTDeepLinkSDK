import Foundation

public enum MRTDeepLinkLicenseStatus: Sendable, Equatable {
    case idle
    case validating
    case valid
    case invalid(message: String)
}

struct MRTDeepLinkLicenseResponse: Decodable, Sendable {
    let valid: Bool
    let message: String?
}

enum MRTDeepLinkLicenseValidator {
    static func validate(
        apiKey: String,
        bundleId: String,
        serverURL: URL,
        validationPath: String
    ) async -> MRTDeepLinkLicenseStatus {
        guard let url = validationURL(serverURL: serverURL, validationPath: validationPath) else {
            return .invalid(message: "Invalid license server URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-MRT-API-Key")
        request.httpBody = try? JSONEncoder().encode(["bundleId": bundleId])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .invalid(message: "Invalid server response")
            }

            if (200...299).contains(httpResponse.statusCode),
               let license = try? JSONDecoder().decode(MRTDeepLinkLicenseResponse.self, from: data),
               license.valid {
                return .valid
            }

            if let license = try? JSONDecoder().decode(MRTDeepLinkLicenseResponse.self, from: data),
               let message = license.message, !message.isEmpty {
                return .invalid(message: message)
            }

            return .invalid(message: "License validation failed (\(httpResponse.statusCode))")
        } catch {
            return .invalid(message: error.localizedDescription)
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
