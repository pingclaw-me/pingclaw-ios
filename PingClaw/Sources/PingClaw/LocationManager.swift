import CoreLocation
import Foundation
import Observation

enum UpdateMode: String, CaseIterable, Sendable {
    case significant = "significant"
    case adaptive = "adaptive"
    case continuous = "continuous"

    var label: String {
        switch self {
        case .significant: "Significant changes only"
        case .adaptive: "Adaptive"
        case .continuous: "Continuous (30s)"
        }
    }

    var description: String {
        switch self {
        case .significant: "Lowest battery — updates on major location changes"
        case .adaptive: "Balanced battery and accuracy"
        case .continuous: "Highest accuracy — updates every 30 seconds"
        }
    }

    var settingsDescription: String {
        switch self {
        case .significant: "Lowest battery use."
        case .adaptive: "Recommended for most people."
        case .continuous: "Most frequent updates."
        }
    }

    var batteryImpact: String {
        switch self {
        case .significant: "~1%/day"
        case .adaptive: "~2%/day"
        case .continuous: "~8%/day"
        }
    }
}

enum ConnectionStatus: Equatable, Sendable {
    case connected
    case disconnected
    case error(String)
}

@MainActor
@Observable
final class LocationManager: NSObject {
    var isTracking = false
    var connection: ConnectionStatus = .disconnected
    var lastUpdateTime: Date?
    var lastAccuracyMetres: Double = 0
    var updateMode: UpdateMode = .adaptive
    var showLocationPermissionPrompt = false

    private let clManager = CLLocationManager()
    private let apiService: APIService
    private let storage: StorageService

    // Minimum seconds between POSTs while in .continuous mode. The streaming
    // Core Location callback fires far more often than this, so we throttle.
    private static let continuousPostInterval: TimeInterval = 30
    // Maximum age of `clManager.location` that we'll POST from
    // requestImmediatePing — older than this we wait for a fresh fix.
    private static let cacheFreshnessWindow: TimeInterval = 60

    init(apiService: APIService, storage: StorageService) {
        self.apiService = apiService
        self.storage = storage
        super.init()
        clManager.delegate = self
        clManager.allowsBackgroundLocationUpdates = true
        clManager.showsBackgroundLocationIndicator = true
        clManager.pausesLocationUpdatesAutomatically = false

        updateMode = storage.updateMode
        if storage.isTracking {
            startTracking()
        }
    }

    func startTracking() {
        let status = clManager.authorizationStatus
        if status == .notDetermined {
            // Show a pre-permission explanation before the system prompt.
            // The view layer observes this flag and shows an alert. When
            // the user confirms, it calls confirmLocationPermission().
            showLocationPermissionPrompt = true
            return
        }

        if status == .denied || status == .restricted {
            connection = .error("Location permission denied")
            storage.isTracking = false
            return
        }

        updateMode = storage.updateMode
        configureForMode(updateMode)

        switch updateMode {
        case .significant:
            clManager.startMonitoringSignificantLocationChanges()
        case .adaptive, .continuous:
            clManager.startUpdatingLocation()
            // Also register for significant changes as a fallback —
            // if iOS terminates the app, this ensures relaunch.
            clManager.startMonitoringSignificantLocationChanges()
        }

        isTracking = true
        storage.isTracking = true

        // Send a location ping immediately
        clManager.requestLocation()
    }

    /// Called by the UI after showing the pre-permission explanation.
    /// Triggers the actual system authorization prompt.
    func confirmLocationPermission() {
        showLocationPermissionPrompt = false
        storage.isTracking = true
        clManager.requestAlwaysAuthorization()
    }

    func requestImmediatePing() {
        // POST whatever location we have right now — the user explicitly
        // asked to share. Also request a fresh fix for next time.
        if let cached = clManager.location {
            handleLocation(cached, force: true)
        }
        clManager.requestLocation()
    }

    func stopTracking() {
        clManager.stopUpdatingLocation()
        clManager.stopMonitoringSignificantLocationChanges()
        isTracking = false
        connection = .disconnected
        storage.isTracking = false
    }

    func changeMode(_ mode: UpdateMode) {
        storage.updateMode = mode
        updateMode = mode
        if isTracking {
            stopTracking()
            startTracking()
        }
    }

    private func configureForMode(_ mode: UpdateMode) {
        switch mode {
        case .significant:
            clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            clManager.distanceFilter = 500
        case .adaptive:
            clManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            clManager.distanceFilter = 50
        case .continuous:
            clManager.desiredAccuracy = kCLLocationAccuracyBest
            clManager.distanceFilter = kCLDistanceFilterNone
        }
    }

    nonisolated private func handleLocation(_ location: CLLocation, force: Bool = false) {
        let accuracy = location.horizontalAccuracy

        Task { @MainActor [weak self] in
            guard let self else { return }

            // Rate-limit POSTs in .continuous mode: the streaming callback
            // fires far more often than we want to hit the server. force=true
            // (manual "Share now") always bypasses.
            if !force, self.updateMode == .continuous,
               let last = self.lastUpdateTime,
               Date().timeIntervalSince(last) < Self.continuousPostInterval {
                return
            }

            self.lastUpdateTime = Date()
            self.lastAccuracyMetres = accuracy

            do {
                try await self.apiService.postLocation(location: location)
                self.connection = .connected
            } catch {
                // If the server returned 401, the pairing token is no
                // longer valid (account deleted or token rotated from
                // another device). APIService already cleared the keychain;
                // stop tracking so the app returns to the sign-in screen.
                if case APIError.serverError(401) = error {
                    self.stopTracking()
                    self.connection = .error("Session expired")
                    return
                }
                self.connection = .error("Failed to reach server")
            }
        }
    }

}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        handleLocation(location)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.connection = .error("Location error: \(error.localizedDescription)")
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                if self.storage.isTracking || self.isTracking {
                    self.startTracking()
                }
            } else if status == .denied || status == .restricted {
                self.connection = .error("Location permission denied")
                self.isTracking = false
                self.storage.isTracking = false
            }
        }
    }
}
