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
    var lastActivity: String = ""
    var updateMode: UpdateMode = .adaptive

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
            // Persist intent so locationManagerDidChangeAuthorization can
            // resume startup once the user grants permission.
            storage.isTracking = true
            clManager.requestAlwaysAuthorization()
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

    func requestImmediatePing() {
        // iOS may suppress requestLocation() if it considers the cached
        // location fresh enough — no didUpdateLocations callback fires,
        // no POST goes out. So we POST the cached location ourselves
        // immediately, AND ask Core Location for a fresh one for next time.
        // Skip the cached post if it's too stale to represent "now".
        if let cached = clManager.location,
           Date().timeIntervalSince(cached.timestamp) < Self.cacheFreshnessWindow {
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
        let speed = location.speed
        let activity = inferActivity(speed: speed)

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
            self.lastActivity = activity

            do {
                try await self.apiService.postLocation(location: location, activity: activity)
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

    nonisolated private func inferActivity(speed: CLLocationSpeed) -> String {
        // Negative speed is CLLocation's "unknown" sentinel; < 0.5 catches it
        // along with actually-stationary readings.
        if speed < 0.5 { return "Stationary" }
        if speed < 3.0 { return "Walking" }
        if speed < 8.0 { return "Cycling" }
        return "In vehicle"
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
