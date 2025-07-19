import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthenticationService()
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                TabBarView()
                    .environmentObject(authService)
            } else {
                OnboardingView()
                    .environmentObject(authService)
            }
        }
        .onAppear {
            authService.checkAuthenticationStatus()
        }
    }
}

#Preview {
    ContentView()
}