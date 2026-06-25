import Foundation

enum MRTNetworkFailure: Error, Sendable {
    case requestFailed(String)
}

enum MRTURLSessionRetry {
    struct HTTPResult: Sendable {
        let data: Data
        let statusCode: Int
    }

    static func data(for request: URLRequest) async -> Result<HTTPResult, MRTNetworkFailure> {
        let maxAttempts = MRTDeepLinkDefaults.apiMaxRetryAttempts
        let initialDelay = MRTDeepLinkDefaults.apiRetryInitialDelay
        var lastError = "Request failed"

        for attempt in 1...maxAttempts {
            if attempt > 1 {
                let delay = retryDelayNanoseconds(attempt: attempt, initialDelay: initialDelay)
                try? await Task.sleep(nanoseconds: delay)
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    lastError = "Invalid server response"
                    if attempt < maxAttempts { continue }
                    return .failure(.requestFailed(lastError))
                }

                let statusCode = httpResponse.statusCode
                if (200...299).contains(statusCode) {
                    return .success(HTTPResult(data: data, statusCode: statusCode))
                }

                if !responseBody(from: data).isEmpty {
                    lastError = "Request failed (\(statusCode)): \(responseBody(from: data))"
                } else {
                    lastError = "Request failed (\(statusCode))"
                }

                if isRetryable(statusCode: statusCode), attempt < maxAttempts {
                    continue
                }
                return .failure(.requestFailed(lastError))
            } catch {
                lastError = error.localizedDescription
                if isRetryable(error: error), attempt < maxAttempts {
                    continue
                }
                return .failure(.requestFailed(lastError))
            }
        }

        return .failure(.requestFailed(lastError))
    }

    static func isRetryable(statusCode: Int) -> Bool {
        if statusCode == 408 || statusCode == 429 { return true }
        if (500...599).contains(statusCode) { return true }
        return false
    }

    static func isRetryable(error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }

    private static func retryDelayNanoseconds(attempt: Int, initialDelay: TimeInterval) -> UInt64 {
        let multiplier = pow(2.0, Double(attempt - 2))
        return UInt64(initialDelay * multiplier * 1_000_000_000)
    }

    private static func responseBody(from data: Data) -> String {
        String(data: data, encoding: .utf8) ?? ""
    }
}
