import Foundation

#if canImport(UIKit)
import UIKit
#endif

public struct MRTDeferredMatchOptions: Sendable {
    public let clickSessionId: String?

    public init(clickSessionId: String? = nil) {
        self.clickSessionId = clickSessionId
    }
}

public struct MRTDeferredMatchResponse: Decodable, Sendable, Equatable {
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
}

public enum MRTDeferredMatchError: Error, Sendable, Equatable, LocalizedError {
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

// Back-compat aliases used by the demo app.
public typealias MRTDeferredMatchDebugOptions = MRTDeferredMatchOptions
public typealias MRTDeferredMatchDebugResponse = MRTDeferredMatchResponse
public typealias MRTDeferredMatchDebugError = MRTDeferredMatchError
public typealias MRTDeferredMatchDebugHandler = (Result<MRTDeferredMatchResponse, MRTDeferredMatchError>) -> Void
public typealias MRTDeferredMatchDebugRequestHandler = (String) -> Void

enum MRTDeferredMatchClient {
    struct RunOutput: Sendable {
        let result: Result<MRTDeferredMatchResponse, MRTDeferredMatchError>
        let requestJSON: String?
    }

    static func run(
        configuration: MRTDeepLinkConfiguration,
        options: MRTDeferredMatchOptions,
        debugLogging: Bool = false
    ) async -> RunOutput {
        guard let url = matchURL(serverURL: configuration.serverURL, matchPath: configuration.deferredMatchPath) else {
            return RunOutput(result: .failure(.message("Invalid deferred match server URL")), requestJSON: nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        MRTSDKRequestAuth.apply(apiKey: configuration.apiKey, to: &request)

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
            MRTSDKRequestAuth.logRequest(name: "Deferred Match", request: request, debugLogging: true)
            if let requestJSON {
                MRTSDKLogger.debug("MATCH BODY \(requestJSON)", enabled: true)
            }
        }

        switch await MRTURLSessionRetry.data(for: request) {
        case .success(let httpResult):
            let rawBody = String(data: httpResult.data, encoding: .utf8) ?? ""
            if debugLogging {
                MRTSDKRequestAuth.logResponse(
                    name: "Deferred Match",
                    statusCode: httpResult.statusCode,
                    body: rawBody,
                    debugLogging: true
                )
            }

            guard (200 ... 299).contains(httpResult.statusCode) else {
                return RunOutput(
                    result: .failure(.message("HTTP \(httpResult.statusCode): \(rawBody.isEmpty ? "empty body" : rawBody)")),
                    requestJSON: requestJSON
                )
            }

            do {
                let decoded = try JSONDecoder().decode(MRTDeferredMatchResponse.self, from: httpResult.data)
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
                return RunOutput(result: .failure(.message(message)), requestJSON: requestJSON)
            }
        }
    }

    static func makeDeferredPayload(
        response: MRTDeferredMatchResponse,
        configuration: MRTDeepLinkConfiguration
    ) -> MRTDeepLinkPayload? {
        guard response.matched, let destinationPath = response.destinationPath, !destinationPath.isEmpty else {
            return nil
        }

        let normalizedPath = destinationPath.hasPrefix("/") ? destinationPath : "/\(destinationPath)"
        let host = configuration.primaryLinkDomain ?? configuration.serverURL.host ?? "localhost"
        guard let url = URL(string: "https://\(host)\(normalizedPath)") else { return nil }

        let pathComponents = normalizedPath
            .split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }

        return MRTDeepLinkPayload(
            url: url,
            path: normalizedPath,
            pathComponents: pathComponents,
            queryParameters: [:],
            source: .deferred,
            isDeferred: true
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
        let osVersionMajor: String
        let deviceModelClass: String
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
        let clockSkewMs: Double?
        let devicePixelRatioBucket: String?
        let canvasHash: String?
        let gpuRenderer: String?
        let audioFingerprint: String?
        let clickSessionId: String?
    }

    private static func makeRequestBody(
        options: MRTDeferredMatchOptions,
        probeDomain: String?,
        debugLogging: Bool
    ) async -> RequestBody {
        let (level, charging) = MRTInstallDeviceInfo.batteryState()
        async let connection = MRTNetworkInfo.connectionType()
        async let webFingerprint = MRTWebFingerprintCollector.collect(
            domain: probeDomain,
            debugLogging: debugLogging
        )
        let connectionType = await connection
        let web = await webFingerprint

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
            osVersionMajor: MRTInstallDeviceInfo.osVersionMajor(),
            deviceModelClass: "ios",
            locale: MRTInstallDeviceInfo.matchLocale(),
            timezone: TimeZone.current.identifier,
            screenBucket: MRTInstallDeviceInfo.screenBucket(),
            appOpenAt: Int64(Date().timeIntervalSince1970 * 1000),
            connectionType: connectionType,
            batteryLevel: level ?? web?.batteryLevel,
            batteryCharging: charging ?? web?.batteryCharging,
            languagesOrdered: Locale.preferredLanguages.joined(separator: ","),
            colorScheme: MRTInstallDeviceInfo.colorScheme(),
            hourCycle: web?.hourCycle,
            currency: web?.currency,
            regionCode: web?.regionCode,
            dynamicTypeSize: MRTInstallDeviceInfo.mapContentSizeCategory() ?? web?.dynamicTypeSize,
            boldText: boldText,
            reduceMotion: reduceMotion,
            increaseContrast: increaseContrast,
            hardwareConcurrency: ProcessInfo.processInfo.processorCount,
            clockSkewMs: web?.clockSkewMs,
            devicePixelRatioBucket: web?.devicePixelRatioBucket,
            canvasHash: web?.canvasHash,
            gpuRenderer: web?.gpuRenderer,
            audioFingerprint: web?.audioFingerprint,
            clickSessionId: options.clickSessionId
        )
    }
}
