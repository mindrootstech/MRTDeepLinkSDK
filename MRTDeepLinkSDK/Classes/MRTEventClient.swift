import Foundation

struct MRTEventPayload: Encodable, Sendable {
    let eventName: String
    let anonymousId: String?
    let userId: String?
    let loginUserId: String?
    let sessionId: String?
    let properties: [String: String]?
}

enum MRTEventError: Error, Sendable {
    case message(String)
}

enum MRTEventClient {
    static func send(
        event: MRTEventPayload,
        configuration: MRTAnalyticsConfiguration
    ) async -> Result<Void, MRTEventError> {
        guard let url = eventsURL(for: configuration) else {
            return .failure(.message("Invalid events server URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        MRTSDKRequestAuth.apply(apiKey: configuration.apiKey, to: &request)

        do {
            request.httpBody = try JSONEncoder().encode(event)
        } catch {
            return .failure(.message("Failed to encode event: \(error.localizedDescription)"))
        }

        if configuration.debugLogging {
            MRTSDKRequestAuth.logHeaders(for: request, label: "Events API", debugLogging: true)
            if let body = request.httpBody, let json = String(data: body, encoding: .utf8) {
                MRTSDKLogger.debug("Events API body: \(json)", enabled: true)
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.message("Invalid server response"))
            }

            let rawBody = String(data: data, encoding: .utf8) ?? ""

            if configuration.debugLogging {
                MRTSDKLogger.debug("Events API status: \(httpResponse.statusCode)", enabled: true)
                if !rawBody.isEmpty {
                    MRTSDKLogger.debug("Events API response: \(rawBody)", enabled: true)
                }
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if rawBody.isEmpty {
                    return .failure(.message("Event logging failed (\(httpResponse.statusCode))"))
                }
                return .failure(.message("Event logging failed (\(httpResponse.statusCode)): \(rawBody)"))
            }

            return .success(())
        } catch {
            return .failure(.message(error.localizedDescription))
        }
    }

    private static func eventsURL(for configuration: MRTAnalyticsConfiguration) -> URL? {
        var components = URLComponents(url: configuration.serverURL, resolvingAgainstBaseURL: false)
        let normalizedPath = configuration.eventsPath.hasPrefix("/")
            ? configuration.eventsPath
            : "/\(configuration.eventsPath)"
        let basePath = components?.path ?? ""

        if basePath.isEmpty || basePath == "/" {
            components?.path = normalizedPath
        } else {
            components?.path = basePath + normalizedPath
        }

        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: configuration.bundleId)
        ]

        return components?.url
    }
}
