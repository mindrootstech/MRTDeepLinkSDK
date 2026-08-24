import Foundation

#if canImport(UIKit)
import UIKit
#endif

public struct CliqItDeferredMatchOptions: Sendable {
    public let clickSessionId: String?

    public init(clickSessionId: String? = nil) {
        self.clickSessionId = clickSessionId
    }
}

/// Typed keys for deferred match response — no stringly printing/checking needed.
public enum CliqItDeferredMatchField: String, CaseIterable, Sendable {
    case matched
    case tier
    case confidence
    case score
    case destinationPath
    case slug
}

/// Switch-friendly deferred match result for integrators.
public enum CliqItDeferredMatchOutcome: Sendable, Equatable {
    case matched(CliqItDeferredMatchInfo)
    case notMatched(CliqItDeferredMatchInfo)
    case failed(CliqItDeferredMatchError)

    public var isMatched: Bool {
        if case .matched = self { return true }
        return false
    }

    public var info: CliqItDeferredMatchInfo? {
        switch self {
        case .matched(let info), .notMatched(let info): return info
        case .failed: return nil
        }
    }

    public var destinationPath: String? {
        info?.destinationPath
    }
}

/// Typed deferred match fields (same data as API response, no optional digging required for path when matched).
public struct CliqItDeferredMatchInfo: Sendable, Equatable {
    public let matched: Bool
    public let tier: String?
    public let confidence: String?
    public let score: Double?
    public let destinationPath: String?
    public let slug: String?

    public init(from response: CliqItDeferredMatchResponse) {
        matched = response.matched
        tier = response.tier
        confidence = response.confidence
        score = response.score
        destinationPath = response.destinationPath
        slug = response.slug
    }

    public subscript(_ field: CliqItDeferredMatchField) -> String? {
        switch field {
        case .matched: return matched ? "true" : "false"
        case .tier: return tier
        case .confidence: return confidence
        case .score: return score.map { String(format: "%.2f", $0) }
        case .destinationPath: return destinationPath
        case .slug: return slug
        }
    }
}

public struct CliqItDeferredMatchResponse: Decodable, Sendable, Equatable {
    public let matched: Bool
    public let tier: String?
    public let confidence: String?
    public let score: Double?
    public let destinationPath: String?
    public let slug: String?

    private enum CodingKeys: String, CodingKey {
        case matched, tier, confidence, score, destinationPath, slug
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        matched = try container.decode(Bool.self, forKey: .matched)
        tier = try container.decodeIfPresent(String.self, forKey: .tier)
        if let string = try? container.decodeIfPresent(String.self, forKey: .confidence) {
            confidence = string
        } else if let number = try? container.decodeIfPresent(Double.self, forKey: .confidence) {
            confidence = String(number)
        } else {
            confidence = nil
        }
        score = try container.decodeIfPresent(Double.self, forKey: .score)
        destinationPath = try container.decodeIfPresent(String.self, forKey: .destinationPath)
        slug = try container.decodeIfPresent(String.self, forKey: .slug)
    }

    public var info: CliqItDeferredMatchInfo { CliqItDeferredMatchInfo(from: self) }

    public var outcome: CliqItDeferredMatchOutcome {
        let info = self.info
        return matched ? .matched(info) : .notMatched(info)
    }

    public subscript(_ field: CliqItDeferredMatchField) -> String? {
        info[field]
    }
}

public enum CliqItDeferredMatchError: Error, Sendable, Equatable, LocalizedError {
    case notConfigured
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "CliqIt is not configured. Call CliqItSDK.shared.configure(apiKey:) before using the SDK."
        case .message(let text):
            return text
        }
    }
}

public typealias CliqItDeferredMatchHandler = (CliqItDeferredMatchOutcome) -> Void

// Back-compat aliases used by the demo app.
public typealias CliqItDeferredMatchDebugOptions = CliqItDeferredMatchOptions
public typealias CliqItDeferredMatchDebugResponse = CliqItDeferredMatchResponse
public typealias CliqItDeferredMatchDebugError = CliqItDeferredMatchError
public typealias CliqItDeferredMatchDebugHandler = (Result<CliqItDeferredMatchResponse, CliqItDeferredMatchError>) -> Void
public typealias CliqItDeferredMatchDebugRequestHandler = (String) -> Void

enum CliqItDeferredMatchClient {
    struct RunOutput: Sendable {
        let result: Result<CliqItDeferredMatchResponse, CliqItDeferredMatchError>
        let requestJSON: String?
    }

    static func run(
        configuration: CliqItConfiguration,
        options: CliqItDeferredMatchOptions,
        debugLogging: Bool = false
    ) async -> RunOutput {
        guard let url = matchURL(serverURL: configuration.serverURL, matchPath: configuration.deferredMatchPath) else {
            return RunOutput(result: .failure(.message("Invalid deferred match server URL")), requestJSON: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        CliqItRequestAuth.apply(apiKey: configuration.apiKey, to: &request)

        let body = await makeRequestBody(
            options: options,
            probeDomain: configuration.fingerprintProbeDomain,
            debugLogging: debugLogging
        )

        let requestJSON: String?
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(body)
            request.httpBody = data
            requestJSON = String(data: data, encoding: .utf8)
        } catch {
            return RunOutput(
                result: .failure(.message("Failed to encode match payload: \(error.localizedDescription)")),
                requestJSON: nil
            )
        }

        if debugLogging {
            CliqItRequestAuth.logRequest(name: "Deferred Match", request: request, debugLogging: true)
            if let requestJSON {
                CliqItLogger.debug("MATCH BODY \(requestJSON)", enabled: true)
            }
        }

        switch await CliqItURLSessionRetry.data(for: request) {
        case .success(let httpResult):
            let rawBody = String(data: httpResult.data, encoding: .utf8) ?? ""
            if debugLogging {
                let pretty = prettyJSON(from: httpResult.data) ?? rawBody
                print("══════════════════════════════════════")
                print("📥 [CliqIt] DEFERRED MATCH RESPONSE")
                print("══════════════════════════════════════")
                print("HTTP \(httpResult.statusCode)")
                print(pretty.isEmpty ? "(empty body)" : pretty)
                print("══════════════════════════════════════")
            }

            guard (200 ... 299).contains(httpResult.statusCode) else {
                return RunOutput(
                    result: .failure(.message("HTTP \(httpResult.statusCode): \(rawBody.isEmpty ? "empty body" : rawBody)")),
                    requestJSON: requestJSON
                )
            }

            do {
                let decoded = try JSONDecoder().decode(CliqItDeferredMatchResponse.self, from: httpResult.data)
                if debugLogging {
                    print("📥 [CliqIt] decoded → matched=\(decoded.matched) tier=\(decoded.tier ?? "-") confidence=\(decoded.confidence ?? "-") score=\(decoded.score.map { String(format: "%.2f", $0) } ?? "-") destinationPath=\(decoded.destinationPath ?? "-") slug=\(decoded.slug ?? "-")")
                }
                return RunOutput(result: .success(decoded), requestJSON: requestJSON)
            } catch {
                return RunOutput(
                    result: .failure(.message("Failed to decode match response: \(error.localizedDescription)")),
                    requestJSON: requestJSON
                )
            }

        case .failure(let error):
            switch error {
            case .requestFailed(let message):
                if debugLogging {
                    print("📥 [CliqIt] DEFERRED MATCH FAILED: \(message)")
                }
                return RunOutput(result: .failure(.message(message)), requestJSON: requestJSON)
            }
        }
    }

    private static func prettyJSON(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: pretty, encoding: .utf8) else {
            return nil
        }
        return string
    }

    /// Unified deferred payload for `onLinkReceived` (matched / notMatched share the same fields).
    static func makeDeferredPayload(
        response: CliqItDeferredMatchResponse,
        configuration: CliqItConfiguration,
        navigate: Bool
    ) -> CliqItPayload {
        let rawPath = response.destinationPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedPath: String = {
            guard !rawPath.isEmpty else { return "" }
            return rawPath.hasPrefix("/") ? rawPath : "/\(rawPath)"
        }()
        let host = configuration.primaryLinkDomain ?? configuration.serverURL.host ?? "localhost"
        let url = URL(string: "https://\(host)\(normalizedPath.isEmpty ? "/" : normalizedPath)")
            ?? configuration.serverURL

        let openPath = (navigate && response.matched && !normalizedPath.isEmpty) ? normalizedPath : ""
        let pathComponents = openPath
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        return CliqItPayload(
            url: url,
            path: openPath,
            pathComponents: pathComponents,
            queryParameters: [:],
            source: .deferred,
            isDeferred: true,
            status: response.matched ? .matched : .notMatched,
            matched: response.matched,
            tier: response.tier,
            confidence: response.confidence,
            score: response.score,
            slug: response.slug,
            destinationPath: normalizedPath.isEmpty ? nil : normalizedPath
        )
    }

    static func makeDeferredFailedPayload(
        error: CliqItDeferredMatchError,
        configuration: CliqItConfiguration
    ) -> CliqItPayload {
        CliqItPayload(
            url: configuration.serverURL,
            path: "",
            pathComponents: [],
            queryParameters: [:],
            source: .deferred,
            isDeferred: true,
            status: .failed,
            matched: false,
            errorMessage: error.localizedDescription
        )
    }

    static func makeVerifyFailedPayload(
        configuration: CliqItConfiguration?,
        message: String
    ) -> CliqItPayload {
        let url = configuration?.serverURL ?? URL(string: "https://theblockyapp.com")!
        return CliqItPayload(
            url: url,
            path: "",
            pathComponents: [],
            queryParameters: [:],
            source: .unknown,
            isDeferred: false,
            status: .verifyFailed,
            errorMessage: message
        )
    }

    static func makeLookupFailedPayload(
        fallback: CliqItPayload,
        message: String
    ) -> CliqItPayload {
        CliqItPayload(
            url: fallback.url,
            path: fallback.path,
            pathComponents: fallback.pathComponents,
            queryParameters: fallback.queryParameters,
            source: fallback.source,
            isDeferred: false,
            status: .lookupFailed,
            slug: fallback.slug,
            destinationPath: fallback.destinationPath,
            errorMessage: message
        )
    }

    private static func matchURL(serverURL: URL, matchPath: String) -> URL? {
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
        let normalizedPath = matchPath.hasPrefix("/") ? matchPath : "/\(matchPath)"
        let basePath = components?.path ?? ""
        components?.path = (basePath.isEmpty || basePath == "/") ? normalizedPath : basePath + normalizedPath
        return components?.url
    }

    private struct RequestBody: Encodable, Sendable {
        let platform: String
        let bundleId: String
        let osVersionMajor: String
        let osVersionMajorMinor: String
        let deviceModelClass: String
        let deviceName: String
        let locale: String
        let timezone: String
        let screenBucket: String
        let appOpenAt: Int64
        let connectionType: String?
        let batteryLevel: Double?
        let batteryCharging: Bool?
        let languagesOrdered: String?
        let colorScheme: String?
        let hourCycle: String?
        let currency: String?
        let regionCode: String?
        let dynamicTypeSize: String?
        let boldText: Bool?
        let reduceMotion: Bool?
        let increaseContrast: Bool?
        let hardwareConcurrency: Int?
        let clockSkewMs: Int?
        let devicePixelRatioBucket: String?
        let canvasHash: String?
        let webglHash: String?
        let webglVendor: String?
        let gpuRenderer: String?
        let audioFingerprint: String?
        let clickSessionId: String?
    }

    private static func makeRequestBody(
        options: CliqItDeferredMatchOptions,
        probeDomain: String?,
        debugLogging: Bool
    ) async -> RequestBody {
        _ = probeDomain
        let (level, charging) = CliqItInstallDeviceInfo.batteryState()
        // Sequential await — avoid `async let` (Swift 6.x / Xcode 26 can abort with
        // "freed pointer was not the last allocation" on child-task teardown).
        let connectionType = await CliqItNetworkInfo.connectionType()
        let web = await CliqItWebFingerprintCollector.collect(debugLogging: debugLogging)

        #if canImport(UIKit)
        let boldText = UIAccessibility.isBoldTextEnabled
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        let increaseContrast = UIAccessibility.isDarkerSystemColorsEnabled
        #else
        let boldText = false
        let reduceMotion = false
        let increaseContrast = false
        #endif

        return RequestBody(
            platform: CliqItSDKIdentity.platform,
            bundleId: CliqItSDKIdentity.bundleId ?? "",
            osVersionMajor: CliqItInstallDeviceInfo.osVersionMajor(),
            osVersionMajorMinor: CliqItInstallDeviceInfo.osVersionMajorMinor(),
            deviceModelClass: "ios",
            deviceName: CliqItInstallDeviceInfo.deviceName(),
            locale: CliqItInstallDeviceInfo.matchLocale(),
            timezone: TimeZone.current.identifier,
            screenBucket: CliqItInstallDeviceInfo.screenBucket(),
            appOpenAt: Int64(Date().timeIntervalSince1970 * 1000),
            connectionType: connectionType,
            batteryLevel: level,
            batteryCharging: charging,
            languagesOrdered: Locale.preferredLanguages.joined(separator: ","),
            colorScheme: CliqItInstallDeviceInfo.colorScheme(),
            hourCycle: CliqItInstallDeviceInfo.hourCycle(),
            currency: CliqItInstallDeviceInfo.currencyCode(),
            regionCode: CliqItInstallDeviceInfo.regionCode(),
            dynamicTypeSize: CliqItInstallDeviceInfo.mapContentSizeCategory(),
            boldText: boldText,
            reduceMotion: reduceMotion,
            increaseContrast: increaseContrast,
            hardwareConcurrency: ProcessInfo.processInfo.processorCount,
            clockSkewMs: web?.clockSkewMs.map { Int($0.rounded()) },
            devicePixelRatioBucket: CliqItInstallDeviceInfo.devicePixelRatioBucket(),
            canvasHash: web?.canvasHash,
            webglHash: web?.webglHash,
            webglVendor: web?.webglVendor,
            gpuRenderer: web?.gpuRenderer,
            audioFingerprint: web?.audioFingerprint,
            clickSessionId: options.clickSessionId
        )
    }
}
