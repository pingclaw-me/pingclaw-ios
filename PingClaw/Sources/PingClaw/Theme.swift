import CoreText
import SwiftUI

// PingClaw — Signal palette, mirroring the web style guide.
// Hex values converted from the canonical CSS variables in
// pingclaw_style_guide.md (section 2 "Colour").

extension Color {
    // Backgrounds
    static let pcBg        = Color(red: 8/255,   green: 14/255,  blue: 12/255)   // #080e0c
    static let pcSurface   = Color(red: 15/255,  green: 26/255,  blue: 24/255)   // #0f1a18
    static let pcSurface2  = Color(red: 22/255,  green: 40/255,  blue: 36/255)   // #162824
    static let pcSurface3  = Color(red: 30/255,  green: 53/255,  blue: 48/255)   // #1e3530

    // Borders
    static let pcBorder    = Color(red: 26/255,  green: 46/255,  blue: 42/255)   // #1a2e2a
    static let pcBorder2   = Color(red: 36/255,  green: 62/255,  blue: 56/255)   // #243e38

    // Accent — teal
    static let pcAccent    = Color(red: 0/255,   green: 194/255, blue: 160/255)  // #00c2a0
    static let pcAccent2   = Color(red: 0/255,   green: 133/255, blue: 110/255)  // #00856e
    static let pcAccent3   = Color(red: 0/255,   green: 96/255,  blue: 79/255)   // #00604f
    static let pcAccentBg  = Color(red: 7/255,   green: 26/255,  blue: 22/255)   // #071a16

    // Text
    static let pcText      = Color(red: 192/255, green: 240/255, blue: 232/255)  // #c0f0e8
    static let pcText2     = Color(red: 122/255, green: 184/255, blue: 172/255)  // #7ab8ac
    static let pcText3     = Color(red: 61/255,  green: 110/255, blue: 102/255)  // #3d6e66
    static let pcText4     = Color(red: 32/255,  green: 72/255,  blue: 64/255)   // #204840

    // Semantic
    static let pcWarning   = Color(red: 200/255, green: 154/255, blue: 26/255)   // #c89a1a
    static let pcError     = Color(red: 200/255, green: 64/255,  blue: 64/255)   // #c84040
    static let pcErrorBg   = Color(red: 26/255,  green: 8/255,   blue: 8/255)    // #1a0808
}

// Register Syne (bundled OFL font) once at app startup so SwiftUI
// `Font.custom("Syne-ExtraBold", ...)` resolves on iOS. SwiftPM resources
// don't auto-populate UIAppFonts, so we register at runtime.
enum PingClawFonts {
    static let register: Void = {
        guard let url = Bundle.module.url(
            forResource: "Syne-VF",
            withExtension: "ttf",
            subdirectory: "Fonts"
        ) else {
            return
        }
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
    }()
}

// Two-tone wordmark — "Ping" in primary text, "Claw" in accent teal.
// Uses Syne ExtraBold (bundled). The .system rounded fallback only kicks
// in if the font failed to register for some reason. When `stacked` is
// true, the two words are rendered on separate lines (matches the
// website hero layout).
struct PingClawWordmark: View {
    var size: CGFloat = 28
    var stacked: Bool = false

    var body: some View {
        Group {
            if stacked {
                // Negative VStack spacing pulls the two Text bounding boxes
                // into each other, mirroring the website's `line-height: 0.88`
                // on .pc-hero-stacked.
                VStack(alignment: .leading, spacing: -size * 0.3) {
                    Text("Ping").foregroundStyle(Color.pcText)
                    Text("Claw").foregroundStyle(Color.pcAccent)
                }
            } else {
                HStack(spacing: 0) {
                    Text("Ping").foregroundStyle(Color.pcText)
                    Text("Claw").foregroundStyle(Color.pcAccent)
                }
            }
        }
        .font(.custom("Syne-ExtraBold", size: size))
    }
}
