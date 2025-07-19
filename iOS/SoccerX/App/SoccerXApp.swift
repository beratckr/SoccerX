import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct SoccerXApp: App {
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}