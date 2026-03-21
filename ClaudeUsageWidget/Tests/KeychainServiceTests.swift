import XCTest
@testable import ClaudeUsageWidget

final class KeychainParsingTests: XCTestCase {

    func testExtractTokenFromValidJSON() throws {
        let json = """
        {
            "claudeAiOauth": {
                "accessToken": "sk-ant-oaut-test-token-12345"
            }
        }
        """.data(using: .utf8)!

        let token = try KeychainService.extractToken(from: json)
        XCTAssertEqual(token, "sk-ant-oaut-test-token-12345")
    }

    func testExtractTokenMissingOAuthKey() {
        let json = """
        {"someOtherKey": {"accessToken": "token"}}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try KeychainService.extractToken(from: json)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidData("No OAuth token found in credentials"))
        }
    }

    func testExtractTokenMissingAccessToken() {
        let json = """
        {"claudeAiOauth": {"refreshToken": "rt-123"}}
        """.data(using: .utf8)!

        XCTAssertThrowsError(try KeychainService.extractToken(from: json)) { error in
            XCTAssertEqual(error as? KeychainError, .invalidData("No OAuth token found in credentials"))
        }
    }

    func testExtractTokenInvalidJSON() {
        let json = "not json at all".data(using: .utf8)!

        XCTAssertThrowsError(try KeychainService.extractToken(from: json)) { error in
            guard let keychainError = error as? KeychainError,
                  case .invalidData = keychainError else {
                XCTFail("Expected invalidData error")
                return
            }
        }
    }
}
