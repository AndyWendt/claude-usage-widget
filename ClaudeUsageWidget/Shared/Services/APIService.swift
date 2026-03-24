import Foundation

final class APIService: APIServiceProtocol {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage(token: String) async throws -> UsageApiResponse {
        var request = URLRequest(url: baseURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(UsageApiResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}

final class CodexAuthService: CodexAuthServiceProtocol {
    private let authFileURL: URL

    init(authFileURL: URL? = nil) {
        if let authFileURL {
            self.authFileURL = authFileURL
        } else {
            self.authFileURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex/auth.json")
        }
    }

    func readAuth() throws -> CodexAuthCredentials {
        guard let data = try? Data(contentsOf: authFileURL) else {
            throw CodexAuthError.notConfigured
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let payload: CodexAuthFile
        do {
            payload = try decoder.decode(CodexAuthFile.self, from: data)
        } catch {
            throw CodexAuthError.invalidData(error.localizedDescription)
        }

        if let authMode = payload.authMode, authMode != "chatgpt" {
            throw CodexAuthError.invalidData("Unsupported auth mode: \(authMode)")
        }

        guard let accessToken = payload.tokens?.accessToken, !accessToken.isEmpty else {
            throw CodexAuthError.invalidData("Missing access token")
        }

        guard let accountID = payload.tokens?.accountId, !accountID.isEmpty else {
            throw CodexAuthError.invalidData("Missing account ID")
        }

        return CodexAuthCredentials(accessToken: accessToken, accountID: accountID)
    }
}

final class CodexAPIService: CodexAPIServiceProtocol {
    private let session: URLSession
    private let baseURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage(credentials: CodexAuthCredentials) async throws -> CodexUsageResponse {
        var request = URLRequest(url: baseURL)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountID, forHTTPHeaderField: "ChatGPT-Account-Id")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CodexUsageResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}

private struct CodexAuthFile: Decodable {
    let authMode: String?
    let tokens: Tokens?

    struct Tokens: Decodable {
        let accessToken: String?
        let accountId: String?
    }
}
