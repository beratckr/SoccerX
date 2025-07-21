import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct SoccerXApp: App {
    
    init() {
        FirebaseApp.configure()
        
        // Initialize Watch connectivity
        _ = WatchConnectivityManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}