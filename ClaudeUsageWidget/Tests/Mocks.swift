import Foundation
@testable import ClaudeUsageWidget

final class MockKeychainService: KeychainServiceProtocol {
    var tokenToReturn: String?
    var errorToThrow: Error?
    var readTokenCallCount = 0

    func readToken() throws -> String {
        readTokenCallCount += 1
        if let error = errorToThrow { throw error }
        guard let token = tokenToReturn else { throw KeychainError.notFound }
        return token
    }
}

final class MockAPIService: APIServiceProtocol {
    var responseToReturn: UsageApiResponse?
    var errorToThrow: Error?
    var lastTokenUsed: String?

    func fetchUsage(token: String) async throws -> UsageApiResponse {
        lastTokenUsed = token
        if let error = errorToThrow { throw error }
        guard let response = responseToReturn else {
            throw APIError.serverError(500)
        }
        return response
    }
}

final class MockStatsService: StatsServiceProtocol {
    var statsToReturn = TokenStats(todayTokens: 0, weekTokens: 0, todayMessages: 0, weekMessages: 0)

    func readStats() -> TokenStats {
        statsToReturn
    }
}

final class MockSharedContainerService: SharedContainerServiceProtocol {
    var storedSnapshot: UsageSnapshot?
    var writeError: Error?

    func writeSnapshot(_ snapshot: UsageSnapshot) throws {
        if let error = writeError { throw error }
        storedSnapshot = snapshot
    }

    func readSnapshot() -> UsageSnapshot? {
        storedSnapshot
    }
}

final class MockWidgetReloader {
    var reloadCount = 0
    func reload() { reloadCount += 1 }
}
