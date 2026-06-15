import Foundation

public typealias MRTDeepLinkHandler = (MRTDeepLinkPayload) -> Void
public typealias MRTDeepLinkLicenseHandler = (MRTDeepLinkLicenseStatus) -> Void

public final class MRTDeepLink: @unchecked Sendable {
    public static let shared = MRTDeepLink()

    private var configuration: MRTDeepLinkConfiguration?
    private var handler: MRTDeepLinkHandler?
    private var licenseHandler: MRTDeepLinkLicenseHandler?
    private var pendingPayload: MRTDeepLinkPayload?
    private var licenseStatus: MRTDeepLinkLicenseStatus = .idle
    private let lock = NSLock()

    private init() {}

    public var isConfigured: Bool {
        lock.lock()
        defer { lock.unlock() }
        return configuration != nil
    }

    public var currentLicenseStatus: MRTDeepLinkLicenseStatus {
        lock.lock()
        defer { lock.unlock() }
        return licenseStatus
    }

    public var isLicenseValid: Bool {
        currentLicenseStatus == .valid
    }

    @discardableResult
    public func configure(_ configuration: MRTDeepLinkConfiguration) -> MRTDeepLink {
        lock.lock()
        self.configuration = configuration
        lock.unlock()

        log("Configured for app: \(configuration.appIdentifier)")
        validateLicense()
        return self
    }

    public func onDeepLink(_ handler: @escaping MRTDeepLinkHandler) {
        lock.lock()
        self.handler = handler
        lock.unlock()

        deliverPendingPayloadIfNeeded()
    }

    public func onLicenseStatusChange(_ handler: @escaping MRTDeepLinkLicenseHandler) {
        lock.lock()
        self.licenseHandler = handler
        let status = licenseStatus
        lock.unlock()

        DispatchQueue.main.async {
            handler(status)
        }
    }

    public func validateLicense() {
        guard let configuration else {
            updateLicenseStatus(.invalid(message: "SDK not configured"))
            return
        }

        updateLicenseStatus(.validating)

        let apiKey = configuration.apiKey
        let bundleId = configuration.appIdentifier
        let serverURL = configuration.licenseServerURL
        let validationPath = configuration.licenseValidationPath

        Task {
            let status = await MRTDeepLinkLicenseValidator.validate(
                apiKey: apiKey,
                bundleId: bundleId,
                serverURL: serverURL,
                validationPath: validationPath
            )
            updateLicenseStatus(status)

            if status == .valid {
                deliverPendingPayloadIfNeeded()
            }
        }
    }

    @discardableResult
    public func handle(url: URL) -> Bool {
        guard isLicenseValid else {
            log("Ignored URL — license is not valid")
            return false
        }

        guard let configuration else {
            log("Received URL before configure(): \(url.absoluteString)")
            return false
        }

        guard let payload = MRTDeepLinkParser.parse(url: url, configuration: configuration) else {
            log("Ignored unsupported URL: \(url.absoluteString)")
            return false
        }

        return deliver(payload)
    }

    @discardableResult
    public func handle(userActivity: NSUserActivity) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        return handle(url: url)
    }

    public func consumePendingDeepLink() -> MRTDeepLinkPayload? {
        guard isLicenseValid else { return nil }

        lock.lock()
        defer { lock.unlock() }
        let payload = pendingPayload
        pendingPayload = nil
        return payload
    }

    @discardableResult
    private func deliver(_ payload: MRTDeepLinkPayload) -> Bool {
        lock.lock()
        let handler = handler
        lock.unlock()

        log("Deep link received: \(payload.url.absoluteString)")

        if let handler {
            DispatchQueue.main.async {
                handler(payload)
            }
            return true
        }

        lock.lock()
        pendingPayload = payload
        lock.unlock()
        return true
    }

    private func deliverPendingPayloadIfNeeded() {
        guard isLicenseValid else { return }

        lock.lock()
        let payload = pendingPayload
        let handler = handler
        lock.unlock()

        guard let payload, let handler else { return }

        lock.lock()
        pendingPayload = nil
        lock.unlock()

        DispatchQueue.main.async {
            handler(payload)
        }
    }

    private func updateLicenseStatus(_ status: MRTDeepLinkLicenseStatus) {
        lock.lock()
        licenseStatus = status
        let handler = licenseHandler
        lock.unlock()

        switch status {
        case .valid:
            log("License validated successfully")
        case .invalid(let message):
            log("License invalid: \(message)")
        case .validating:
            log("Validating license…")
        case .idle:
            break
        }

        guard let handler else { return }
        DispatchQueue.main.async {
            handler(status)
        }
    }

    private func log(_ message: String) {
        lock.lock()
        let shouldLog = configuration?.debugLogging == true
        lock.unlock()
        guard shouldLog else { return }
        print("[MRTDeepLinkSDK] \(message)")
    }
}
