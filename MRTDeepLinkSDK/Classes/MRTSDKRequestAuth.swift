import Foundation

enum MRTSDKRequestAuth {
    static func apply(apiKey: String, to request: inout URLRequest) {
        request.setValue(apiKey, forHTTPHeaderField: MRTDeepLinkDefaults.sdkKeyHeader)
        request.setValue(
            MRTDeepLinkDefaults.authorizationValue(apiKey: apiKey),
            forHTTPHeaderField: MRTDeepLinkDefaults.authorizationHeader
        )
    }

    static func logHeaders(for request: URLRequest, label: String) {
        print("[MRTDeepLinkSDK] \(label) headers:")
        guard let headers = request.allHTTPHeaderFields, !headers.isEmpty else {
            print("[MRTDeepLinkSDK]   (none)")
            return
        }

        for key in headers.keys.sorted() {
            print("[MRTDeepLinkSDK]   \(key): \(headers[key] ?? "")")
        }
    }
}
