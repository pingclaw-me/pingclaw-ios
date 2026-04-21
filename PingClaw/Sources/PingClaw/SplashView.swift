import SwiftUI

/// Full-screen branded splash shown briefly at launch. Displays the
/// wordmark centered on the paper background.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()
            WordmarkView(size: .large)
        }
    }
}
