import Foundation

#if canImport(UIKit)
import UIKit
#endif

/// Clipboard-based exact match token for deferred deep linking.
///
/// Strategy (matches Branch's low-prompt approach):
/// 1. `detectPatterns([.probableWebURL])` — metadata only, **no** iOS paste prompt.
/// 2. Only if a web URL is actually present do we read the pasteboard (the single prompt),
///    so the prompt appears only for users who arrived through a copied SmartLink.
///
/// The web page must copy the SmartLink URL (e.g. `https://…/r/xxxx?session=<uuid>`) to the
/// clipboard on click; we parse `session` / `clickSessionId` / `click_session_id` from it.
enum MRTClipboardMatchToken {
    /// Silent metadata check — does the clipboard hold something that looks like a web URL?
    /// Never triggers the paste prompt. Returns false off-iOS or on error.
    static func webURLLikelyPresent() async -> Bool {
        #if canImport(UIKit)
        await withCheckedContinuation { continuation in
            UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { result in
                switch result {
                case .success(let patterns):
                    continuation.resume(returning: patterns.contains(.probableWebURL))
                case .failure:
                    continuation.resume(returning: false)
                }
            }
        }
        #else
        return false
        #endif
    }

    /// Reads the clipboard (triggers the iOS paste prompt) and extracts a match token.
    /// Call only after `webURLLikelyPresent()` returns true.
    static func read() async -> String? {
        #if canImport(UIKit)
        let raw: String? = await MainActor.run {
            UIPasteboard.general.string ?? UIPasteboard.general.url?.absoluteString
        }
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return token(from: raw)
        #else
        return nil
        #endif
    }

    /// Combined: silent detect, then read only if a URL is present. Zero prompts when no link.
    static func readIfLinkPresent() async -> String? {
        guard await webURLLikelyPresent() else { return nil }
        return await read()
    }

    /// Extracts a session token from a copied SmartLink URL, or accepts a bare UUID.
    static func token(from raw: String) -> String? {
        if let url = URL(string: raw), url.scheme != nil,
           let session = MRTDeepLinkParser.parseClickSessionId(from: url) {
            return session
        }
        if UUID(uuidString: raw) != nil {
            return raw
        }
        return nil
    }
}
