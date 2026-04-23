import CoreLocation
import Foundation

struct LocationPayload: Encodable, Sendable {
    let timestamp: String
    let location: LocationCoords
    // Only present on test pings from Settings > "Send test update" so the
    // server can skip storing them as real location history. Optional so
    // real pings serialize identically to the pre-existing wire format.
    let test: Bool?

    struct LocationCoords: Encodable, Sendable {
        let lat: Double
        let lng: Double
        let accuracy_metres: Double
    }
}

@MainActor
final class APIService {
    private let storage: StorageService

    init(storage: StorageService) {
        self.storage = storage
    }

    func postLocation(location: CLLocation) async throws {
        let payload = LocationPayload(
            timestamp: ISO8601DateFormatter().string(from: location.timestamp),
            location: .init(
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                accuracy_metres: location.horizontalAccuracy
            ),
            test: nil
        )

        try await sendWithRetry(payload: payload)
    }

    func sendTestUpdate() async throws {
        let payload = LocationPayload(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            location: .init(lat: 0, lng: 0, accuracy_metres: 0),
            test: true
        )

        try await sendWithRetry(payload: payload)
    }

    private func sendWithRetry(payload: LocationPayload) async throws {
        let token = storage.getPairingToken()
        guard let token, !token.isEmpty else {
            throw APIError.noToken
        }

        let serverUrl = storage.serverUrl
        guard let url = URL(string: "\(serverUrl)/pingclaw/location") else {
            throw APIError.serverError(0)
        }
        let body = try JSONEncoder().encode(payload)

        do {
            try await doPost(url: url, token: token, body: body)
        } catch let error where Self.isTransient(error) {
            // Retry once after 2 seconds for network blips or 5xx. A 4xx
            // (bad token, bad payload) won't be fixed by retrying.
            try await Task.sleep(nanoseconds: 2_000_000_000)
            try await doPost(url: url, token: token, body: body)
        }
    }

    private static func isTransient(_ error: Error) -> Bool {
        if error is URLError { return true }
        if case APIError.serverError(let code) = error, code >= 500 { return true }
        return false
    }

    private func doPost(url: URL, token: String, body: Data) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            // 401 means the token is no longer valid — the account was
            // deleted from the dashboard or the token was rotated. Clear
            // local credentials so the app returns to the sign-in screen.
            if code == 401 {
                storage.clearAll()
            }
            throw APIError.serverError(code)
        }
    }

    // MARK: - Social auth

    /// Sends a provider identity token to the server for verification.
    /// On success the server creates (or finds) the user and returns a
    /// pairing_token the app stores in the keychain.
    func socialSignIn(provider: String, idToken: String) async throws -> String {
        let serverUrl = storage.serverUrl
        guard let url = URL(string: "\(serverUrl)/pingclaw/auth/social") else {
            throw APIError.serverError(0)
        }
        let payload: [String: String] = [
            "provider": provider,
            "id_token": idToken,
            "client": "ios",
        ]
        let body = try JSONEncoder().encode(payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.serverError(code)
        }

        struct Response: Decodable { let pairing_token: String }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.pairing_token
    }

    /// Requests a short-lived web login code from the server. The user
    /// types this code into the web dashboard to sign in there.
    func requestWebCode() async throws -> String {
        let token = storage.getPairingToken()
        guard let token, !token.isEmpty else {
            throw APIError.noToken
        }
        let serverUrl = storage.serverUrl
        guard let url = URL(string: "\(serverUrl)/pingclaw/auth/web-code") else {
            throw APIError.serverError(0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.serverError(code)
        }

        struct Response: Decodable { let code: String }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.code
    }

    // MARK: - Account

    func deleteAccount() async throws {
        let token = storage.getPairingToken()
        guard let token, !token.isEmpty else {
            throw APIError.noToken
        }

        let serverUrl = storage.serverUrl
        guard let url = URL(string: "\(serverUrl)/pingclaw/auth/account") else {
            throw APIError.serverError(0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw APIError.serverError(code)
        }
    }

}

enum APIError: LocalizedError, Sendable {
    case noToken
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .noToken: "No pairing token"
        case .serverError(let code): "Server returned \(code)"
        }
    }
}
