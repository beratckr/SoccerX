import Foundation
import SwiftUI
import AuthenticationServices
import FirebaseAuth
import CryptoKit
import Combine

class AuthenticationService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Unhashed nonce for Apple Sign In
    private var currentNonce: String?
    private let userRepository = UserRepository()
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        if let firebaseUser = Auth.auth().currentUser {
            // Load user from Firestore
            loadUserFromFirestore(uid: firebaseUser.uid)
        } else {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    private func loadUserFromFirestore(uid: String) {
        isLoading = true
        userRepository.getCurrentUser(uid: uid)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] (completion: Subscribers.Completion<RepositoryError>) in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = "Failed to load user: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] (user: User?) in
                    if let user = user {
                        self?.currentUser = user
                        self?.isAuthenticated = true
                    } else {
                        // User document doesn't exist, this shouldn't happen after sign-in
                        self?.isAuthenticated = false
                        self?.currentUser = nil
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func signInWithApple() {
        let nonce = randomNonceString()
        currentNonce = nonce
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.isAuthenticated = false
            self.currentUser = nil
            self.errorMessage = nil
        } catch {
            self.errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
    
    private func authenticateWithFirebase(identityToken: String, authorizationCode: String, user: ASAuthorizationAppleIDCredential) {
        isLoading = true
        errorMessage = nil
        
        guard let nonce = currentNonce else {
            self.errorMessage = "Invalid state: A login callback was received, but no login request was sent."
            return
        }
        
        // Create Apple credential
        let credential = OAuthProvider.appleCredential(withIDToken: identityToken,
                                                      rawNonce: nonce,
                                                      fullName: user.fullName)
        
        // Sign in with Firebase Auth directly
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isLoading = false
                    self?.errorMessage = "Authentication failed: \(error.localizedDescription)"
                    return
                }
                
                guard let authResult = authResult else {
                    self?.isLoading = false
                    self?.errorMessage = "No authentication result received"
                    return
                }
                
                // Create or update user document in Firestore
                self?.createOrUpdateUserDocument(
                    firebaseUser: authResult.user,
                    appleUser: user
                )
            }
        }
    }
    
    private func createOrUpdateUserDocument(firebaseUser: FirebaseAuth.User, appleUser: ASAuthorizationAppleIDCredential) {
        // First check if user already exists
        userRepository.getCurrentUser(uid: firebaseUser.uid)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] (completion: Subscribers.Completion<RepositoryError>) in
                    if case .failure(let error) = completion {
                        print("Error checking existing user: \(error)")
                        // Continue with creating new user
                        self?.createNewUserDocument(firebaseUser: firebaseUser, appleUser: appleUser)
                    }
                },
                receiveValue: { [weak self] (existingUser: User?) in
                    if let existingUser = existingUser {
                        // User exists, just set the current user and authenticate
                        self?.currentUser = existingUser
                        self?.isAuthenticated = true
                        self?.isLoading = false
                        self?.errorMessage = nil
                    } else {
                        // User doesn't exist, create new user document
                        self?.createNewUserDocument(firebaseUser: firebaseUser, appleUser: appleUser)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func createNewUserDocument(firebaseUser: FirebaseAuth.User, appleUser: ASAuthorizationAppleIDCredential) {
        // Create display name from Apple ID credential
        let displayName: String
        if let fullName = appleUser.fullName {
            let firstName = fullName.givenName ?? ""
            let lastName = fullName.familyName ?? ""
            displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        } else {
            displayName = firebaseUser.email?.components(separatedBy: "@").first ?? "Soccer Player"
        }
        
        // Create new User object using the convenience initializer
        var newUser = User(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            displayName: displayName.isEmpty ? "Soccer Player" : displayName
        )
        
        // Set the document ID
        newUser.id = firebaseUser.uid
        
        // Save to Firestore
        userRepository.create(newUser)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] (completion: Subscribers.Completion<RepositoryError>) in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = "Failed to create user: \(error.localizedDescription)"
                    }
                },
                receiveValue: { [weak self] (createdUser: User) in
                    self?.currentUser = createdUser
                    self?.isAuthenticated = true
                    self?.errorMessage = nil
                }
            )
            .store(in: &cancellables)
    }
}

extension AuthenticationService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authorizationCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            errorMessage = "Failed to get Apple ID credentials"
            return
        }
        
        authenticateWithFirebase(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            user: appleIDCredential
        )
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                return
            case .failed:
                errorMessage = "Apple Sign In failed"
            case .invalidResponse:
                errorMessage = "Invalid response from Apple"
            case .notHandled:
                errorMessage = "Apple Sign In not handled"
            case .unknown:
                errorMessage = "Unknown Apple Sign In error"
            @unknown default:
                errorMessage = "Unknown Apple Sign In error"
            }
        } else {
            errorMessage = "Apple Sign In error: \(error.localizedDescription)"
        }
    }
}

extension AuthenticationService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// MARK: - Helper Functions
extension AuthenticationService {
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}