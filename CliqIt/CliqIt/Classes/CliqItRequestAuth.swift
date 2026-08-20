import Foundation

enum CliqItRequestAuth {
    static func apply(apiKey: String, to request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: CliqItDefaults.apiKeyHeader)
    }

    static func logRequest(name: String, request: URLRequest, debugLogging: Bool) {
        guard debugLogging else { return }
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "(invalid)"
        CliqItLogger.debug("[\(name)] \(method) \(url)", enabled: true)
        if let body = request.httpBody, let json = String(data: body, encoding: .utf8), !json.isEmpty {
            CliqItLogger.debug("[\(name)] body: \(json)", enabled: true)
        }
    }

    static func logResponse(name: String, statusCode: Int, body: String, debugLogging: Bool) {
        guard debugLogging else { return }
        let preview = body.isEmpty ? "(empty)" : body
        CliqItLogger.debug("[\(name)] \(statusCode) \(preview)", enabled: true)
    }
}
