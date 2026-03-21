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
