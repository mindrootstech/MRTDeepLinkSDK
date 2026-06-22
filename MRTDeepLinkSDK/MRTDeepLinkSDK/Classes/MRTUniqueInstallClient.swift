import Foundation

struct MRTUniqueInstallRequestBody: Encodable, Sendable {
    let deviceId: String
    let platform: String
    let osVersion: String

    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case platform
        case osVersion = "os_version"
    }
}

struct MRTUniqueInstallResult: Sendable {
    let installId: String?
    let isNew: Bool
    let uniqueCounted: Bool
    let message: String?
}

enum MRTUniqueInstallError: Error, Sendable {
    case message(String)
}

enum MRTUniqueInstallClient {
    static func report(
        configuration: MRTDeepLinkConfiguration,
        uniqueInstallPath: String = MRTDeepLinkDefaults.uniqueInstallPath,
        debugLogging: Bool = false
    ) async -> Result<MRTUniqueInstallResult, MRTUniqueInstallError> {
        guard let url = uniqueInstallURL(
            serverURL: configuration.licenseServerURL,
            uniqueInstallPath: uniqueInstallPath,
            bundleId: configuration.appIdentifier
        ) else {
            return .failure(.message("Invalid unique install server URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        MRTSDKRequestAuth.apply(apiKey: configuration.apiKey, to: &request)

        let body = MRTUniqueInstallRequestBody(
            deviceId: MRTInstallDeviceInfo.stableDeviceId(),
            platform: MRTInstallDeviceInfo.platform,
            osVersion: MRTInstallDeviceInfo.osVersion
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return .failure(.message("Failed to encode unique install payload: \(error.localizedDescription)"))
        }

        if debugLogging {
            MRTSDKRequestAuth.logHeaders(for: request, label: "Unique Install API", debugLogging: true)
            if let json = String(data: request.httpBody ?? Data(), encoding: .utf8) {
                MRTSDKLogger.debug("Unique Install API body: \(json)", enabled: true)
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.message("Invalid server response"))
            }

            let rawBody = String(data: data, encoding: .utf8) ?? ""

            if debugLogging {
                MRTSDKLogger.debug("Unique Install API status: \(httpResponse.statusCode)", enabled: true)
                if !rawBody.isEmpty {
                    MRTSDKLogger.debug("Unique Install API response: \(rawBody)", enabled: true)
                }
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if rawBody.isEmpty {
                    return .failure(.message("Unique install reporting failed (\(httpResponse.statusCode))"))
                }
                return .failure(.message("Unique install reporting failed (\(httpResponse.statusCode)): \(rawBody)"))
            }

            let decoded = try JSONDecoder().decode(MRTUniqueInstallAPIResponse.self, from: data)
            guard let payload = decoded.data else {
                return .failure(.message("Unique install response missing data"))
            }

            return .success(
                MRTUniqueInstallResult(
                    installId: payload.installId,
                    isNew: payload.isNew == true,
                    uniqueCounted: payload.uniqueCounted == true,
                    message: payload.message
                )
            )
        } catch let error as DecodingError {
            return .failure(.message("Failed to decode unique install response: \(error.localizedDescription)"))
        } catch {
            return .failure(.message(error.localizedDescription))
        }
    }

    private static func uniqueInstallURL(
        serverURL: URL,
        uniqueInstallPath: String,
        bundleId: String
    ) -> URL? {
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
        let normalizedPath = uniqueInstallPath.hasPrefix("/")
            ? uniqueInstallPath
            : "/\(uniqueInstallPath)"
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

private struct MRTUniqueInstallAPIResponse: Decodable {
    let success: Bool?
    let data: MRTUniqueInstallAPIData?
}

private struct MRTUniqueInstallAPIData: Decodable {
    let installId: String?
    let isNew: Bool?
    let uniqueCounted: Bool?
    let message: String?
}
