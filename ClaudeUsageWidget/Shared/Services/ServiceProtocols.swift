import Foundation

protocol KeychainServiceProtocol {
    func readToken() throws -> String
}

protocol APIServiceProtocol {
    func fetchUsage(token: String) async throws -> UsageApiResponse
}

protocol CodexAuthServiceProtocol {
    func readAuth() throws -> CodexAuthCredentials
}

protocol CodexAPIServiceProtocol {
    func fetchUsage(credentials: CodexAuthCredentials) async throws -> CodexUsageResponse
}

protocol StatsServiceProtocol {
    func readStats() -> TokenStats
}

protocol SharedContainerServiceProtocol {
    func writeSnapshot(_ snapshot: UsageSnapshot) throws
    func readSnapshot() -> UsageSnapshot?
    func writePaceSettings(_ settings: PaceSettings) throws
    func readPaceSettings() -> PaceSettings
}

enum KeychainError: Error, Equatable {
    case notFound
    case accessDenied
    case invalidData(String)
}

enum APIError: Error, Equatable {
    case unauthorized
    case forbidden
    case serverError(Int)
    case networkError(String)
    case decodingError(String)
}

enum CodexAuthError: Error, Equatable {
    case notConfigured
    case invalidData(String)
}
