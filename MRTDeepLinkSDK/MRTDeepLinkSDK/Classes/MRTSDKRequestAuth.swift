import Foundation

enum MRTSDKRequestAuth {
    static func apply(apiKey: String, to request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: MRTDeepLinkDefaults.sdkKeyHeader)
        request.setValue(
            MRTDeepLinkDefaults.authorizationValue(apiKey: apiKey),
            forHTTPHeaderField: MRTDeepLinkDefaults.authorizationHeader
        )
    }

    static func logHeaders(for request: URLRequest, label: String, debugLogging: Bool) {
        guard debugLogging else { return }

        MRTSDKLogger.debug("\(label) headers:", enabled: true)
        guard let headers = request.allHTTPHeaderFields, !headers.isEmpty else {
            MRTSDKLogger.debug("  (none)", enabled: true)
            return
        }

        for key in headers.keys.sorted() {
            let value = headers[key] ?? ""
            let sanitized = sensitiveHeaderKeys.contains(key) ? redacted(value) : value
            MRTSDKLogger.debug("  \(key): \(sanitized)", enabled: true)
        }
    }

    private static let sensitiveHeaderKeys: Set<String> = [
        MRTDeepLinkDefaults.sdkKeyHeader,
        MRTDeepLinkDefaults.authorizationHeader
    ]

    private static func redacted(_ value: String) -> String {
        guard value.count > 8 else { return "****" }
        return String(value.prefix(4)) + "****" + String(value.suffix(4))
    }
}
