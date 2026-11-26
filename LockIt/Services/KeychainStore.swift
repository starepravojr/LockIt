import Foundation
import Security

/// The paired card and the Emergency Unbrick counter. They live in the
/// Keychain because its items outlast deleting and reinstalling the app.
struct KeychainStore {
    static let initialEmergencyUnbricks = 5

    private enum Account {
        static let pairedCardUID = "pairedCardUID"
        static let emergencyUnbricks = "emergencyUnbricksRemaining"
    }

    private let service: String

    init(service: String = AppConfig.keychainService) {
        self.service = service
    }

    var pairedCardUID: String? {
        guard let data = try? read(Account.pairedCardUID) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func setPairedCardUID(_ uid: String) throws {
        try write(Data(uid.utf8), for: Account.pairedCardUID)
    }

    /// Starts at `initialEmergencyUnbricks`. If the Keychain cannot be read,
    /// this reports 0 rather than hand out a fresh allowance.
    var emergencyUnbricksRemaining: Int {
        do {
            guard let data = try read(Account.emergencyUnbricks) else {
                return Self.initialEmergencyUnbricks
            }
            return String(data: data, encoding: .utf8).flatMap(Int.init) ?? 0
        } catch {
            return 0
        }
    }

    func setEmergencyUnbricksRemaining(_ count: Int) throws {
        try write(Data(String(max(0, count)).utf8), for: Account.emergencyUnbricks)
    }

    /// Returns nil when there is no item for the account.
    private func read(_ account: String) throws -> Data? {
        var query = baseQuery(for: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError(status: status)
        }
    }

    private func write(_ data: Data, for account: String) throws {
        let query = baseQuery(for: account)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData] = data
            item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private func baseQuery(for account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
    }
}

struct KeychainError: LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        let reason = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
        return "The Keychain couldn't be updated (\(reason))."
    }
}
