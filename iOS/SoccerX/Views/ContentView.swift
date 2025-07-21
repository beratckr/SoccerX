import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthenticationService()
    
    var body: some View {
        if authService.isAuthenticated {
            TabBarView()
                .environmentObject(authService)
        } else {
            OnboardingView()
                .environmentObject(authService)
        }
    }
}

#Preview {
    ContentView()
}