import XCTest
@testable import ClaudeUsageRingCore

final class TokenReaderTests: XCTestCase {
    let credsJSON = #"{ "claudeAiOauth": { "accessToken": "AT-999", "refreshToken": "RT" } }"#

    func testExtractAccessToken() {
        let t = TokenReader.extractAccessToken(fromJSON: Data(credsJSON.utf8))
        XCTAssertEqual(t, "AT-999")
    }

    func testKeychainWinsOverFile() throws {
        let creds = credsJSON
        let reader = TokenReader(
            keychainReader: { creds },
            fileReader: { Data(#"{ "claudeAiOauth": { "accessToken": "FILE" } }"#.utf8) }
        )
        XCTAssertEqual(try reader.token(), "AT-999")
    }

    func testFallsBackToFile() throws {
        let reader = TokenReader(
            keychainReader: { nil },
            fileReader: { Data(#"{ "claudeAiOauth": { "accessToken": "FILE" } }"#.utf8) }
        )
        XCTAssertEqual(try reader.token(), "FILE")
    }

    func testBothMissingThrows() {
        let reader = TokenReader(keychainReader: { nil }, fileReader: { nil })
        XCTAssertThrowsError(try reader.token()) { err in
            XCTAssertEqual(err as? TokenError, .notFound)
        }
    }

    func testSecurityToolReadUsesAppleToolWithExactArguments() {
        let box = CallBox()
        let out = TokenReader.readViaSecurityTool { url, args in
            box.url = url
            box.args = args
            return (0, Data("  {\"claudeAiOauth\":{\"accessToken\":\"AT\"}}\n".utf8))
        }
        XCTAssertEqual(box.url?.path, "/usr/bin/security")
        XCTAssertEqual(box.args, ["find-generic-password", "-s", "Claude Code-credentials", "-w"])
        XCTAssertEqual(out, #"{"claudeAiOauth":{"accessToken":"AT"}}"#)
    }

    func testSecurityToolFailureReturnsNil() {
        XCTAssertNil(TokenReader.readViaSecurityTool { _, _ in (44, Data()) })
        XCTAssertNil(TokenReader.readViaSecurityTool { _, _ in (0, Data("\n".utf8)) })
        XCTAssertNil(TokenReader.readViaSecurityTool { _, _ in nil })
    }

    func testHexEncodedKeychainOutputIsDecoded() throws {
        let hex = Data(credsJSON.utf8).map { String(format: "%02x", $0) }.joined()
        let reader = TokenReader(keychainReader: { hex }, fileReader: { nil })
        XCTAssertEqual(try reader.token(), "AT-999")
    }
}

private final class CallBox: @unchecked Sendable {
    var url: URL?
    var args: [String]?
}
