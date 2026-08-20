import Foundation

/// Single identity check from `/api/v1/sdk/verify`.
public struct CliqItVerifyCheck: Decodable, Sendable, Equatable {
    public let actual: String?
    public let expected: String?
    public let match: Bool

    public var summary: String {
        "actual=\(actual ?? "nil") expected=\(expected ?? "nil") match=\(match)"
    }
}

/// Known check keys from verify response.
public enum CliqItVerifyCheckField: String, CaseIterable, Sendable {
    case bundleId
    case packageName
    case androidSha256
}

public struct CliqItVerifyResult: Decodable, Sendable, Equatable {
    public let ok: Bool
    public let appId: String?
    public let appName: String?
    public let checks: [String: CliqItVerifyCheck]

    public var failedChecks: [(field: String, check: CliqItVerifyCheck)] {
        checks
            .filter { !$0.value.match }
            .map { ($0.key, $0.value) }
            .sorted { $0.field < $1.field }
    }

    public var mismatchMessage: String {
        guard !ok else { return "Verify OK" }
        if failedChecks.isEmpty {
            return "Verify failed (ok=false)"
        }
        return failedChecks
            .map { "\($0.field): actual=\($0.check.actual ?? "-") expected=\($0.check.expected ?? "-")" }
            .joined(separator: "; ")
    }

    public subscript(_ field: CliqItVerifyCheckField) -> CliqItVerifyCheck? {
        checks[field.rawValue]
    }
}

public enum CliqItVerifyOutcome: Sendable, Equatable {
    /// Server returned `ok: true`.
    case passed(CliqItVerifyResult)
    /// Server returned `ok: false` (identity mismatch) — integrator must fix apiKey / bundle / package / SHA.
    case mismatched(CliqItVerifyResult)
    /// Network / decode failure.
    case error(CliqItDeferredMatchError)

    public var isOk: Bool {
        if case .passed = self { return true }
        return false
    }

    public var result: CliqItVerifyResult? {
        switch self {
        case .passed(let r), .mismatched(let r): return r
        case .error: return nil
        }
    }
}

public typealias CliqItVerifyHandler = (CliqItVerifyOutcome) -> Void

/// Background `POST /api/v1/sdk/verify` after `configure(apiKey:)`.
enum CliqItVerifyClient {
    private struct Body: Encodable {
        let platform: String
        let bundleId: String?
        let packageName: String?
        let androidSha256: String?
    }

    static func verifyInBackground(
        configuration: CliqItConfiguration,
        completion: @escaping (CliqItVerifyOutcome, String?) -> Void
    ) {
        Task {
            let (outcome, raw) = await run(configuration: configuration)
            await MainActor.run { completion(outcome, raw) }
        }
    }

    @discardableResult
    static func run(configuration: CliqItConfiguration) async -> (CliqItVerifyOutcome, String?) {
        guard var url = URL(string: configuration.serverURL.absoluteString) else {
            return (.error(.message("Invalid server URL")), nil)
        }
        for part in CliqItDefaults.verifyPath.split(separator: "/").map(String.init).filter({ !$0.isEmpty }) {
            url.appendPathComponent(part)
        }

        let body = Body(
            platform: CliqItSDKIdentity.platform,
            bundleId: CliqItSDKIdentity.bundleId,
            packageName: nil,
            androidSha256: nil
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        CliqItRequestAuth.apply(apiKey: configuration.apiKey, to: &request)

        do {
            request.httpBody = try encodeOmittingNulls(body)
        } catch {
            let msg = "Failed to encode verify payload: \(error.localizedDescription)"
            print("❌ [CliqIt] verify error: \(msg)")
            return (.error(.message(msg)), nil)
        }

        switch await CliqItURLSessionRetry.data(for: request) {
        case .failure(let error):
            switch error {
            case .requestFailed(let message):
                print("❌ [CliqIt] verify error: \(message)")
                return (.error(.message(message)), nil)
            }
        case .success(let http):
            let bodyText = String(data: http.data, encoding: .utf8) ?? ""

            do {
                let decoded = try JSONDecoder().decode(CliqItVerifyResult.self, from: http.data)
                if decoded.ok {
                    print("✅ [CliqIt] verify OK — \(decoded.appName ?? "app") (\(decoded.appId ?? "-"))")
                    return (.passed(decoded), bodyText)
                } else {
                    print("❌ [CliqIt] verify MISMATCH (ok=false)")
                    print("   appName: \(decoded.appName ?? "-")")
                    print("   appId:   \(decoded.appId ?? "-")")
                    for (field, check) in decoded.failedChecks {
                        print("   • \(field): actual=\(check.actual ?? "-") expected=\(check.expected ?? "-")")
                    }
                    print("   Fix: use this app's API key, or match Bundle ID / package / SHA in admin.")
                    return (.mismatched(decoded), bodyText)
                }
            } catch {
                let msg = "Invalid verify response: \(error.localizedDescription)"
                print("❌ [CliqIt] verify error: \(msg)")
                if !bodyText.isEmpty { print("   body: \(bodyText)") }
                return (.error(.message(msg)), bodyText)
            }
        }
    }

    private static func encodeOmittingNulls<T: Encodable>(_ value: T) throws -> Data {
        let data = try JSONEncoder().encode(value)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return data
        }
        let cleaned = object.filter { !($0.value is NSNull) }
        return try JSONSerialization.data(withJSONObject: cleaned, options: [.sortedKeys])
    }
}
