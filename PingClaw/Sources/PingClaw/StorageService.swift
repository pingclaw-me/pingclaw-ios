import Foundation
import Security

@MainActor
final class StorageService {
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let updateMode = "update_mode"
        static let serverUrl = "server_url"
        static let isTracking = "is_tracking"
        static let googleClientID = "google_client_id"
    }

    private static let keychainService = "me.pingclaw.app"
    private static let keychainAccount = "pairing_token"

    var updateMode: UpdateMode {
        get {
            guard let raw = defaults.string(forKey: Keys.updateMode),
                  let mode = UpdateMode(rawValue: raw)
            else { return .adaptive }
            return mode
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.updateMode)
        }
    }

    var serverUrl: String {
        get {
            defaults.string(forKey: Keys.serverUrl) ?? "https://pingclaw.me"
        }
        set {
            defaults.set(newValue, forKey: Keys.serverUrl)
        }
    }

    var isTracking: Bool {
        get { defaults.bool(forKey: Keys.isTracking) }
        set { defaults.set(newValue, forKey: Keys.isTracking) }
    }

    /// Google OAuth client ID. Set this to the web client ID from the
    /// Google Cloud Console. Empty string disables Google sign-in.
    var googleClientID: String {
        // iOS uses the iOS-type client ID (custom URL schemes allowed).
        // Web uses the Web-type client ID (set in the meta tag + server env).
        get { defaults.string(forKey: Keys.googleClientID) ?? "339229829038-hli9moca58el3r2sboog5545njfnqddd.apps.googleusercontent.com" }
        set { defaults.set(newValue, forKey: Keys.googleClientID) }
    }

    // MARK: - Keychain (pairing token)

    func savePairingToken(_ token: String) -> Bool {
        deletePairingToken()
        guard let data = token.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecValueData as String: data,
            // AFTER_FIRST_UNLOCK allows background access
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    func getPairingToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    func deletePairingToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    /// Wipes every piece of user state this app persists — keychain token
    /// and all UserDefaults keys. Used when the user taps "Delete All
    /// Data" so a subsequent pairing cannot be correlated back to the
    /// deleted identity.
    func clearAll() {
        deletePairingToken()
        defaults.removeObject(forKey: Keys.updateMode)
        defaults.removeObject(forKey: Keys.serverUrl)
        defaults.removeObject(forKey: Keys.isTracking)
    }
}
