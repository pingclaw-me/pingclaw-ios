import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

/// The sign-in screen shown when no pairing token exists. Offers Sign
/// in with Apple (native), Sign in with Google (via browser PKCE), and
/// self-hosted token pairing.
struct SignInView: View {
    var storage: StorageService
    var onSignedIn: () -> Void

    @State private var isSigningIn = false
    @State private var errorMessage: String?
    @State private var showSelfHost = false

    var body: some View {
        ZStack {
            Color.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer(minLength: 40)

                    // Wordmark
                    WordmarkView(size: .medium)
                        .padding(.bottom, 28)
                        .padding(.horizontal, 24)

                    // Headline
                    (Text("A quiet ")
                        .foregroundColor(Color.ink)
                     + Text("location source")
                        .foregroundColor(Color.rust)
                        .italic()
                     + Text(" for your AI agent.")
                        .foregroundColor(Color.ink))
                    .font(Typography.display(34, weight: .regular))
                    .lineSpacing(2)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                    // Subtitle
                    Text("Install once. Your agent knows where you are — until you decide it shouldn't.")
                        .font(Typography.body(14))
                        .foregroundStyle(Color.inkSoft)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 36)

                    // Trust bullets
                    VStack(alignment: .leading, spacing: 4) {
                        trustBullet("Coordinates only, never a map")
                        trustBullet("Cached for 24 hours, never stored in a database")
                        trustBullet("Delete everything any time")
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                    // Sign in buttons
                    VStack(spacing: 10) {
                        // Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = []
                        } onCompletion: { result in
                            handleAppleResult(result)
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                        .cornerRadius(Spacing.buttonRadius)
                        .accessibilityLabel("Sign in with Apple")

                        // Google
                        Button { startGoogleSignIn() } label: {
                            HStack(spacing: 8) {
                                Text("G").font(.system(size: 16, weight: .bold))
                                Text("Sign in with Google")
                                    .font(Typography.body(15, weight: .medium))
                            }
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .overlay(
                                RoundedRectangle(cornerRadius: Spacing.buttonRadius)
                                    .stroke(Color.ink, lineWidth: 1)
                            )
                        }
                        .disabled(isSigningIn)
                        .accessibilityLabel("Sign in with Google")
                    }
                    .padding(.horizontal, 24)

                    // Loading / error
                    if isSigningIn {
                        HStack {
                            Spacer()
                            ProgressView().tint(Color.rust)
                            Spacer()
                        }
                        .padding(.top, 16)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typography.caption(12))
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.horizontal, 24)
                    }

                    // Self-hosting divider
                    HStack(spacing: 12) {
                        Rectangle().fill(Color.rule).frame(height: 1)
                        Text("OR SELF-HOSTING")
                            .font(Typography.monoSmall())
                            .tracking(1.3)
                            .foregroundStyle(Color.inkFaint)
                        Rectangle().fill(Color.rule).frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)

                    // Self-host row
                    Button { showSelfHost = true } label: {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connect to your own server")
                                    .font(Typography.rowTitle())
                                    .foregroundStyle(Color.ink)
                                Text("No Apple or Google account needed")
                                    .font(Typography.caption(12))
                                    .foregroundStyle(Color.inkSoft)
                            }
                            Spacer()
                            Text("\u{203A}")
                                .font(.custom("Fraunces", size: 18))
                                .foregroundStyle(Color.inkGhost)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    // Legal
                    Text("By continuing, you agree to the [Terms](https://pingclaw.me/termsofservice) and [Privacy Policy](https://pingclaw.me/privacypolicy).")
                        .font(Typography.caption(11))
                        .foregroundStyle(Color.inkFaint)
                        .tint(Color.inkSoft)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.top, 22)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationDestination(isPresented: $showSelfHost) {
            SelfHostView(storage: storage, onSignedIn: onSignedIn)
                .navigationBarHidden(true)
        }
    }

    // MARK: - Trust bullet

    private func trustBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.rust)
                .frame(width: 10, height: 1)
                .padding(.top, 9)
            Text(text)
                .font(Typography.caption())
                .foregroundStyle(Color.inkSoft)
                .lineSpacing(2)
        }
    }

    // MARK: - Apple Sign-In

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Could not read Apple identity token."
                return
            }
            sendToServer(provider: "apple", idToken: idToken)

        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Google Sign-In (PKCE authorization code flow)

    @State private var webAuthSession: ASWebAuthenticationSession?

    private func startGoogleSignIn() {
        let clientID = storage.googleClientID
        guard !clientID.isEmpty else {
            errorMessage = "Google sign-in is not configured."
            return
        }

        let reversedClientID = clientID.components(separatedBy: ".").reversed().joined(separator: ".")
        let redirectScheme = reversedClientID
        let redirectURI = "\(reversedClientID):/oauthredirect"

        let codeVerifier = generateCodeVerifier()
        let codeChallenge = sha256Base64URL(codeVerifier)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "openid"),
            .init(name: "code_challenge", value: codeChallenge),
            .init(name: "code_challenge_method", value: "S256"),
        ]

        guard let url = components.url else {
            errorMessage = "Could not build Google OAuth URL."
            return
        }

        let session = ASWebAuthenticationSession(url: url, callbackURLScheme: redirectScheme) { callbackURL, error in
            if let error {
                if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue { return }
                errorMessage = "Google sign-in failed: \(error.localizedDescription)"
                return
            }
            guard let callbackURL,
                  let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems,
                  let code = queryItems.first(where: { $0.name == "code" })?.value else {
                errorMessage = "Could not read Google authorization code."
                return
            }
            exchangeGoogleCode(code, clientID: clientID, redirectURI: redirectURI, codeVerifier: codeVerifier)
        }
        session.prefersEphemeralWebBrowserSession = true
        session.presentationContextProvider = WebAuthContextProvider.shared
        session.start()
        webAuthSession = session
    }

    private func exchangeGoogleCode(_ code: String, clientID: String, redirectURI: String, codeVerifier: String) {
        isSigningIn = true
        Task {
            do {
                let body = [
                    "code": code,
                    "client_id": clientID,
                    "redirect_uri": redirectURI,
                    "grant_type": "authorization_code",
                    "code_verifier": codeVerifier,
                ]
                let bodyData = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
                    .joined(separator: "&")
                    .data(using: .utf8)!

                var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = bodyData

                let (data, _) = try await URLSession.shared.data(for: request)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let idToken = json["id_token"] as? String else {
                    errorMessage = "Could not get ID token from Google."
                    isSigningIn = false
                    return
                }
                sendToServer(provider: "google", idToken: idToken)
            } catch {
                errorMessage = "Google token exchange failed: \(error.localizedDescription)"
                isSigningIn = false
            }
        }
    }

    // MARK: - PKCE helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func sha256Base64URL(_ input: String) -> String {
        let hash = SHA256.hash(data: Data(input.utf8))
        return Data(hash).base64URLEncoded()
    }

    // MARK: - Server call

    private func sendToServer(provider: String, idToken: String) {
        isSigningIn = true
        errorMessage = nil
        let api = APIService(storage: storage)

        Task {
            do {
                let pairingToken = try await api.socialSignIn(provider: provider, idToken: idToken)
                guard storage.savePairingToken(pairingToken) else {
                    errorMessage = "Could not save the pairing token to the keychain."
                    isSigningIn = false
                    return
                }
                isSigningIn = false
                onSignedIn()
            } catch {
                errorMessage = "Sign-in failed: \(error.localizedDescription)"
                isSigningIn = false
            }
        }
    }
}

// MARK: - ASWebAuthenticationSession presentation anchor

private final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthContextProvider()
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

// MARK: - Base64-URL encoding

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
