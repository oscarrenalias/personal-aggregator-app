import Foundation
import Security

/// Thin wrapper around `kSecClassGenericPassword` Keychain items.
///
/// All operations target the shared keychain access group
/// (`net.renalias.AggregatorApp.shared`) so the widget extension
/// can read credentials written by the main app.
///
/// `write` is upsert: attempts `SecItemAdd`; on `errSecDuplicateItem`
/// falls back to `SecItemUpdate`.
struct KeychainHelper {
    private static let sharedAccessGroup = "QEZ63CXN26.net.renalias.AggregatorApp.shared"
    private static let legacyAccessGroup = "QEZ63CXN26.net.renalias.AggregatorApp"
    private static let migrationDefaultsKey = "KeychainSharedGroupMigrationDone"

    static func read(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrAccessGroup: sharedAccessGroup,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let addQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrAccessGroup: sharedAccessGroup,
            kSecValueData: data
        ]
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            let searchQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
                kSecAttrAccessGroup: sharedAccessGroup
            ]
            SecItemUpdate(searchQuery as CFDictionary, [kSecValueData: data] as CFDictionary)
        }
    }

    static func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecAttrAccessGroup: sharedAccessGroup
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// One-time migration of keychain items from the app's default group into
    /// the shared access group so the widget extension can read them.
    ///
    /// Call once at app launch, **before** any other `KeychainHelper` usage.
    /// Safe to call multiple times — runs only on the first launch after update.
    static func migrateToSharedGroupIfNeeded(keys: [String]) {
        guard !UserDefaults.standard.bool(forKey: migrationDefaultsKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: migrationDefaultsKey) }

        for key in keys {
            // Read without restricting access group — finds item in legacy default group.
            let readQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne
            ]
            var result: AnyObject?
            guard SecItemCopyMatching(readQuery as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else { continue }

            // Write to shared group first so the credential is never lost.
            write(key: key, value: value)

            // Delete from legacy default group.
            let deleteQuery: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrAccount: key,
                kSecAttrAccessGroup: legacyAccessGroup
            ]
            SecItemDelete(deleteQuery as CFDictionary)
        }
    }
}
