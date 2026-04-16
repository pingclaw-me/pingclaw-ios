import CoreLocation
import Foundation
#if os(iOS)
import UIKit
#endif

struct LocationPayload: Encodable, Sendable {
    let timestamp: String
    let location: LocationCoords
    let activity: String
    let device_id: String
    let battery_pct: Int
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

    func postLocation(location: CLLocation, activity: String) async throws {
        let payload = LocationPayload(
            timestamp: ISO8601DateFormatter().string(from: location.timestamp),
            location: .init(
                lat: location.coordinate.latitude,
                lng: location.coordinate.longitude,
                accuracy_metres: location.horizontalAccuracy
            ),
            activity: activity,
            device_id: storage.deviceId,
            battery_pct: getBatteryLevel(),
            test: nil
        )

        try await sendWithRetry(payload: payload)
    }

    func sendTestUpdate() async throws {
        let payload = LocationPayload(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            location: .init(lat: 0, lng: 0, accuracy_metres: 0),
            activity: "Test",
            device_id: storage.deviceId,
            battery_pct: -1,
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
            throw APIError.serverError(code)
        }
    }

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

    private func getBatteryLevel() -> Int {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level >= 0 ? Int(level * 100) : -1
        #else
        return -1
        #endif
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
