import XCTest
@testable import ClaudeUsageWidget

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class APIServiceTests: XCTestCase {
    var service: APIService!
    var codexService: CodexAPIService!

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        service = APIService(session: URLSession(configuration: config))
        codexService = CodexAPIService(session: URLSession(configuration: config))
    }

    func testFetchUsageSuccess() async throws {
        let responseJSON = """
        {
            "five_hour": {"utilization": 45.5, "resets_at": "2026-03-21T18:00:00Z"},
            "seven_day": {"utilization": 30.0, "resets_at": "2026-03-25T00:00:00Z"}
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJSON)
        }

        let result = try await service.fetchUsage(token: "test-token")
        XCTAssertEqual(result.fiveHour?.utilization, 45.5)
        XCTAssertEqual(result.sevenDay?.utilization, 30.0)
    }

    func testFetchUsage401ThrowsUnauthorized() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.fetchUsage(token: "bad-token")
            XCTFail("Expected unauthorized error")
        } catch APIError.unauthorized {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchUsage403ThrowsForbidden() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.fetchUsage(token: "bad-token")
            XCTFail("Expected forbidden error")
        } catch APIError.forbidden {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchUsageMalformedJSON() async {
        let badJSON = "{ not valid json at all".data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, badJSON)
        }

        do {
            _ = try await service.fetchUsage(token: "test-token")
            XCTFail("Expected decoding error")
        } catch APIError.decodingError(let message) {
            XCTAssertFalse(message.isEmpty, "Decoding error should include a description")
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testFetchUsage500ThrowsServerError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await service.fetchUsage(token: "token")
            XCTFail("Expected server error")
        } catch APIError.serverError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCodexFetchUsageSuccess() async throws {
        let responseJSON = """
        {
            "rate_limit": {
                "allowed": true,
                "limit_reached": false,
                "primary_window": {"used_percent": 15, "limit_window_seconds": 18000, "reset_after_seconds": 4180, "reset_at": 1774388998}
            }
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://chatgpt.com/backend-api/wham/usage")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer codex-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "account-123")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, responseJSON)
        }

        let result = try await codexService.fetchUsage(
            credentials: CodexAuthCredentials(accessToken: "codex-token", accountID: "account-123")
        )

        XCTAssertEqual(result.rateLimit.primaryWindow?.usedPercent, 15)
    }

    func testCodexAuthServiceReadsChatGPTCredentials() throws {
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let authFile = tmpDir.appendingPathComponent("auth.json")
        let json = """
        {
            "auth_mode": "chatgpt",
            "tokens": {
                "access_token": "codex-token",
                "account_id": "account-123"
            }
        }
        """
        try json.write(to: authFile, atomically: true, encoding: .utf8)

        let authService = CodexAuthService(authFileURL: authFile)
        let credentials = try authService.readAuth()

        XCTAssertEqual(credentials.accessToken, "codex-token")
        XCTAssertEqual(credentials.accountID, "account-123")
    }
}
