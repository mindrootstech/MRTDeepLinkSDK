import Foundation

enum MRTSDKRequestAuth {
    static func apply(apiKey: String, to request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: MRTDeepLinkDefaults.sdkKeyHeader)
        request.setValue(
            MRTDeepLinkDefaults.authorizationValue(apiKey: apiKey),
            forHTTPHeaderField: MRTDeepLinkDefaults.authorizationHeader
        )
        request.setValue("true", forHTTPHeaderField: "Ngrok-Skip-Browser-Warning")
    }

    static func logRequest(name: String, request: URLRequest, debugLogging: Bool) {
        guard debugLogging else { return }
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "(invalid)"
        MRTSDKLogger.debug("[\(name)] \(method) \(url)", enabled: true)
        if let body = request.httpBody, let json = String(data: body, encoding: .utf8), !json.isEmpty {
            MRTSDKLogger.debug("[\(name)] body: \(json)", enabled: true)
        }
    }

    static func logResponse(name: String, statusCode: Int, body: String, debugLogging: Bool) {
        guard debugLogging else { return }
        let preview = body.isEmpty ? "(empty)" : body
        MRTSDKLogger.debug("[\(name)] \(statusCode) \(preview)", enabled: true)
    }
}
