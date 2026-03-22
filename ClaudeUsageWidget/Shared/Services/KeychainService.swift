import Foundation
import Security

final class KeychainService: KeychainServiceProtocol {

    func readToken() throws -> String {
        // Try macOS Keychain first
        if let token = try? readFromKeychain() {
            return token
        }

        // Fall back to credentials file
        if let token = try? readFromCredentialsFile() {
            return token
        }

        throw KeychainError.notFound
    }

    private func readFromKeychain() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecAttrAccount as String: NSUserName(),
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData("Unexpected Keychain data format")
            }
            return try Self.extractToken(from: data)
        case errSecItemNotFound:
            throw KeychainError.notFound
        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw KeychainError.accessDenied
        default:
            throw KeychainError.invalidData("Keychain error: \(status)")
        }
    }

    private func readFromCredentialsFile() throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let credPath = home.appendingPathComponent(".claude/.credentials.json")
        let data = try Data(contentsOf: credPath)
        return try Self.extractToken(from: data)
    }

    static func extractToken(from data: Data) throws -> String {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw KeychainError.invalidData("Failed to parse credentials JSON: \(error.localizedDescription)")
        }

        guard let dict = json as? [String: Any],
              let oauth = dict["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw KeychainError.invalidData("No OAuth token found in credentials")
        }

        return token
    }
}
