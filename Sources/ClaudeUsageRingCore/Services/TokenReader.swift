import Foundation

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

    // Live reader: Keychain via `security`, then ~/.claude/.credentials.json.
    public static let live = TokenReader(
        keychainReader: {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            p.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = Pipe()
            do { try p.run() } catch { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            let s = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? nil : s
        },
        fileReader: {
            let path = (NSString(string: "~/.claude/.credentials.json").expandingTildeInPath)
            return try? Data(contentsOf: URL(fileURLWithPath: path))
        }
    )
}
