import SwiftUI

@main
struct PingClawApp: App {
    @State private var storage = StorageService()
    @State private var locationManager: LocationManager
    @State private var showPairingSuccess = false
    @State private var pairingError: String?
    @State private var showSplash = true

    init() {
        // Register the bundled Syne font so PingClawWordmark can use it.
        // Touching the static `register` constant runs the registration once.
        _ = PingClawFonts.register

        let s = StorageService()
        let api = APIService(storage: s)
        _storage = State(wrappedValue: s)
        _locationManager = State(wrappedValue: LocationManager(apiService: api, storage: s))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(locationManager: locationManager, storage: storage)
                    .onOpenURL { url in
                        handleDeepLink(url)
                    }

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
                .alert("Paired Successfully", isPresented: $showPairingSuccess) {
                    Button("Start Sharing") {
                        locationManager.startTracking()
                    }
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Your pairing token has been saved. You can start sharing your location now.")
                }
                .alert("Pairing Failed", isPresented: .init(
                    get: { pairingError != nil },
                    set: { if !$0 { pairingError = nil } }
                )) {
                    Button("OK") { pairingError = nil }
                } message: {
                    Text(pairingError ?? "")
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "pingclaw", url.host == "pair" else { return }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
              !token.isEmpty else { return }

        guard storage.savePairingToken(token) else {
            pairingError = "Could not save the pairing token to the keychain. Please try again."
            return
        }
        if locationManager.isTracking {
            // Token updated while tracking — send a ping immediately
            locationManager.requestImmediatePing()
        } else {
            showPairingSuccess = true
        }
    }
}
