import Foundation
#if canImport(Security)
import Security
#endif

public enum TokenError: Error, Equatable {
    case notFound
}

public struct TokenReader: Sendable {
    private let keychainReader: @Sendable () -> String?
    private let fileReader: @Sendable () -> Data?

    public init(keychainReader: @escaping @Sendable () -> String?,
                fileReader: @escaping @Sendable () -> Data?) {
        self.keychainReader = keychainReader
        self.fileReader = fileReader
    }

    public func token() throws -> String {
        if let raw = keychainReader(), let t = Self.extractAccessToken(fromJSON: Data(raw.utf8)) {
            return t
        }
        if let data = fileReader(), let t = Self.extractAccessToken(fromJSON: data) {
            return t
        }
        throw TokenError.notFound
    }

    public static func extractAccessToken(fromJSON data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let oauth = root["claudeAiOauth"] as? [String: Any],
           let token = oauth["accessToken"] as? String {
            return token
        }
        // Fallback shapes seen across versions.
        if let token = root["accessToken"] as? String { return token }
        return nil
    }

    /// Keychain service name Claude Code stores its credentials under.
    public static let keychainService = "Claude Code-credentials"

    // Live reader: Keychain via the Security framework, then
    // ~/.claude/.credentials.json. Reading the item directly (rather than via
    // the `security` CLI) attributes the macOS consent prompt to this app, so
    // a signed build shows a real identity and "Always Allow" persists.
    public static let live = TokenReader(
        keychainReader: {
            #if canImport(Security)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: TokenReader.keychainService,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess, let data = item as? Data else { return nil }
            let s = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
            #else
            return nil
            #endif
        },
        fileReader: {
            let path = (NSString(string: "~/.claude/.credentials.json").expandingTildeInPath)
            return try? Data(contentsOf: URL(fileURLWithPath: path))
        }
    )
}
