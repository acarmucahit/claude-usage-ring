import Foundation

public enum TokenError: Error, Equatable {
    case notFound
}

public struct TokenReader: Sendable {
    /// Runs an executable and returns its exit status and stdout, or nil if it
    /// could not be launched.
    public typealias CommandRunner = @Sendable (URL, [String]) -> (status: Int32, stdout: Data)?

    private let keychainReader: @Sendable () -> String?
    private let fileReader: @Sendable () -> Data?

    public init(keychainReader: @escaping @Sendable () -> String?,
                fileReader: @escaping @Sendable () -> Data?) {
        self.keychainReader = keychainReader
        self.fileReader = fileReader
    }

    public func token() throws -> String {
        if let raw = keychainReader(), let t = Self.extractAccessToken(fromKeychainOutput: raw) {
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

    /// `security -w` prints the item as text, or as hex when the data is not
    /// plain printable text.
    static func extractAccessToken(fromKeychainOutput raw: String) -> String? {
        if let t = extractAccessToken(fromJSON: Data(raw.utf8)) { return t }
        guard let bytes = hexDecoded(raw) else { return nil }
        return extractAccessToken(fromJSON: bytes)
    }

    private static func hexDecoded(_ s: String) -> Data? {
        let chars = Array(s.utf8)
        guard !chars.isEmpty, chars.count % 2 == 0 else { return nil }
        var out = Data(capacity: chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let hi = hexValue(chars[i]), let lo = hexValue(chars[i + 1]) else { return nil }
            out.append(hi << 4 | lo)
            i += 2
        }
        return out
    }

    private static func hexValue(_ c: UInt8) -> UInt8? {
        switch c {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return c - UInt8(ascii: "0")
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return c - UInt8(ascii: "a") + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return c - UInt8(ascii: "A") + 10
        default: return nil
        }
    }

    /// Keychain service name Claude Code stores its credentials under.
    public static let keychainService = "Claude Code-credentials"

    static let securityTool = URL(fileURLWithPath: "/usr/bin/security")

    /// Claude Code writes its Keychain item with Apple's `security` tool, so
    /// macOS already trusts that tool for the item. Reading through it never
    /// shows a Keychain consent dialog, whereas reading the item directly from
    /// this app does — and an ad-hoc signed app can't keep "Always Allow".
    public static func readViaSecurityTool(run: CommandRunner = runCommand) -> String? {
        let args = ["find-generic-password", "-s", keychainService, "-w"]
        guard let result = run(securityTool, args), result.status == 0 else { return nil }
        let s = String(decoding: result.stdout, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    public static let runCommand: CommandRunner = { url, args in
        let p = Process()
        p.executableURL = url
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        p.standardInput = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return (p.terminationStatus, data)
    }

    public static let live = TokenReader(
        keychainReader: { readViaSecurityTool() },
        fileReader: {
            let path = (NSString(string: "~/.claude/.credentials.json").expandingTildeInPath)
            return try? Data(contentsOf: URL(fileURLWithPath: path))
        }
    )
}
