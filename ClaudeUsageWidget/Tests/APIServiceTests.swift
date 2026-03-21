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

    override func setUp() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        service = APIService(session: URLSession(configuration: config))
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
}
