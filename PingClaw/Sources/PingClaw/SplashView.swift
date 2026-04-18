import SwiftUI

/// Full-screen branded splash shown briefly at launch. Displays the
/// hero banner (icon + wordmark + tagline) centered on the app
/// background, using the appropriate image for light/dark mode.
struct SplashView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color.pcBg.ignoresSafeArea()

            if let uiImage = heroImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 32)
            }
        }
    }

    private var heroImage: UIImage? {
        let name = colorScheme == .dark ? "Hero" : "HeroLight"
        guard let url = Bundle.module.url(forResource: name, withExtension: "png"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
