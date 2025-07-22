import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore

@main
struct SoccerXApp: App {
    
    init() {
        print("🚀 SoccerXApp initializing...")
        
        // Configure Firebase FIRST before anything else
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("✅ Firebase configured successfully")
            
            // Configure Firestore settings ONCE here
            let settings = FirestoreSettings()
            settings.cacheSettings = PersistentCacheSettings(sizeBytes: FirestoreCacheSizeUnlimited as NSNumber)
            Firestore.firestore().settings = settings
            print("✅ Firestore settings configured")
        } else {
            print("⚠️ Firebase already configured")
        }
        
        // Initialize Watch connectivity after Firebase is configured
        DispatchQueue.main.async {
            _ = WatchConnectivityManager.shared
        }
        print("✅ SoccerXApp initialized successfully")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}