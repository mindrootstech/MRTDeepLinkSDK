import Foundation

struct MRTEventPayload: Codable, Sendable {
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
        configuration: MRTAnalyticsConfiguration,
        debugLogging: Bool? = nil
    ) async -> Result<Void, MRTEventError> {
        let shouldLog = debugLogging ?? configuration.debugLogging
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

        if shouldLog {
            MRTSDKRequestAuth.logHeaders(for: request, label: "Events API", debugLogging: true)
            if let body = request.httpBody, let json = String(data: body, encoding: .utf8) {
                MRTSDKLogger.debug("Events API body: \(json)", enabled: true)
            }
        }

        let result = await MRTURLSessionRetry.data(for: request)
        switch result {
        case .success(let httpResult):
            let rawBody = String(data: httpResult.data, encoding: .utf8) ?? ""
            if shouldLog {
                MRTSDKLogger.debug("Events API status: \(httpResult.statusCode)", enabled: true)
                if !rawBody.isEmpty {
                    MRTSDKLogger.debug("Events API response: \(rawBody)", enabled: true)
                }
            }
            return .success(())
        case .failure(let error):
            switch error {
            case .requestFailed(let message):
                return .failure(.message(message))
            }
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
