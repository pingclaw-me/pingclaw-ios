import SwiftUI

/// Full-screen branded splash shown briefly at launch. Displays the
/// hero banner (icon + wordmark + tagline) centered on the app's dark
/// background, then fades out to reveal ContentView.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color.pcBg.ignoresSafeArea()

            if let url = Bundle.module.url(forResource: "Hero", withExtension: "png"),
               let data = try? Data(contentsOf: url),
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 32)
            }
        }
        .preferredColorScheme(.dark)
    }
}
