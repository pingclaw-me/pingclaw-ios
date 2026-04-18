import SwiftUI

/// Full-screen branded splash shown briefly at launch. Matches the
/// app's dark background so the transition from the system launch
/// screen is seamless, then fades out to reveal ContentView.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.pcBg.ignoresSafeArea()

            VStack(spacing: 12) {
                PingClawWordmark(size: 48, stacked: true)
                Text("Location context for AI")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.pcText2)
            }
        }
        .preferredColorScheme(.dark)
    }
}
