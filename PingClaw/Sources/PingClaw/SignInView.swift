import AuthenticationServices
import CryptoKit
import Foundation
import SwiftUI

/// The sign-in screen shown when no pairing token exists. Offers Sign
/// in with Apple (native) and Sign in with Google (via browser sheet).
/// On success, stores the pairing_token in the keychain and calls the
/// `onSignedIn` closure.
struct SignInView: View {
    var storage: StorageService
    var onSignedIn: () -> Void

    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            // Sign in with Apple — native button
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = []
            } onCompletion: { result in
                handleAppleResult(result)
            }
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(height: 50)
            .cornerRadius(8)
            .accessibilityLabel("Sign in with Apple")

            // Sign in with Google — styled to match
            Button {
                startGoogleSignIn()
            } label: {
                HStack(spacing: 8) {
                    Text("G")
                        .font(.title3.bold())
                    Text("Sign in with Google")
                        .font(.body.weight(.medium))
                }
                .foregroundStyle(Color.pcText)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.pcSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.pcBorder, lineWidth: 1)
                )
                .cornerRadius(8)
            }
            .disabled(isSigningIn)
            .accessibilityLabel("Sign in with Google")

            if isSigningIn {
                ProgressView()
                    .tint(Color.pcAccent)
                    .padding(.top, 8)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.pcError)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 24)
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
            // ASAuthorizationError.canceled is normal (user dismissed)
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

        // iOS-type Google client IDs use the reversed client ID as the
        // redirect scheme and require PKCE (no client secret).
        let reversedClientID = clientID.components(separatedBy: ".").reversed().joined(separator: ".")
        let redirectScheme = reversedClientID
        let redirectURI = "\(reversedClientID):/oauthredirect"

        // PKCE: generate code_verifier + code_challenge
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
        webAuthSession = session // retain
    }

    /// Exchanges the authorization code for an id_token at Google's
    /// token endpoint, then sends the id_token to our server.
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

// MARK: - Base64-URL encoding (no padding, URL-safe alphabet)

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
