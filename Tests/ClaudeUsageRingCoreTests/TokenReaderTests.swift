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
}
