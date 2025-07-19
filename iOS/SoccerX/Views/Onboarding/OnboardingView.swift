import SwiftUI
import AuthenticationServices

struct OnboardingView: View {
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App Logo and Title
            VStack(spacing: 20) {
                Image(systemName: "soccerball")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("SoccerX")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your soccer games like never before")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Sign in with Apple Button
            VStack(spacing: 20) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    // Handle result in AuthenticationService
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(25)
                .padding(.horizontal)
                
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
                
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Terms and Privacy
            VStack(spacing: 8) {
                Text("By signing in, you agree to our")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 0) {
                    Button("Terms of Service") {
                        // Handle terms
                    }
                    .font(.caption)
                    
                    Text(" and ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Privacy Policy") {
                        // Handle privacy
                    }
                    .font(.caption)
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
        .onTapGesture {
            authService.signInWithApple()
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthenticationService())
}