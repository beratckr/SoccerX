import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    let uid: String
    var displayName: String
    var email: String
    var profileImageUrl: String?
    var fcmToken: String?
    var stats: UserStats
    var achievements: [String] // Achievement IDs
    var groupIds: [String]
    var isPremium: Bool
    @ServerTimestamp var createdAt: Timestamp?
    @ServerTimestamp var updatedAt: Timestamp?
    
    // Computed properties
    var initials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: displayName) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        return String(displayName.prefix(2)).uppercased()
    }
    
    // Initialize with default values
    init(uid: String, email: String, displayName: String) {
        self.uid = uid
        self.email = email
        self.displayName = displayName
        self.stats = UserStats()
        self.achievements = []
        self.groupIds = []
        self.isPremium = false
    }
}

struct UserStats: Codable, Equatable {
    var totalGames: Int = 0
    var totalDistance: Double = 0 // in kilometers
    var totalDuration: Int = 0 // in seconds
    var averageMVPScore: Double = 0
    var highestMVPScore: Double = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var totalCalories: Int = 0
    var favoritePlayTime: String? // e.g., "evening", "morning"
    @ServerTimestamp var lastGameDate: Timestamp?
    
    // Computed properties
    var totalDistanceFormatted: String {
        String(format: "%.1f km", totalDistance)
    }
    
    var totalDurationFormatted: String {
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
    
    var averageMVPScoreFormatted: String {
        String(format: "%.0f", averageMVPScore)
    }
}

// MARK: - Firestore Extensions
extension User {
    // Convert to Firestore data
    func toFirestore() -> [String: Any] {
        var data: [String: Any] = [
            "uid": uid,
            "displayName": displayName,
            "email": email,
            "stats": stats.toDictionary(),
            "achievements": achievements,
            "groupIds": groupIds,
            "isPremium": isPremium
        ]
        
        if let profileImageUrl = profileImageUrl {
            data["profileImageUrl"] = profileImageUrl
        }
        
        if let fcmToken = fcmToken {
            data["fcmToken"] = fcmToken
        }
        
        if createdAt == nil {
            data["createdAt"] = FieldValue.serverTimestamp()
        }
        
        data["updatedAt"] = FieldValue.serverTimestamp()
        
        return data
    }
}

extension UserStats {
    func toDictionary() -> [String: Any] {
        var data: [String: Any] = [
            "totalGames": totalGames,
            "totalDistance": totalDistance,
            "totalDuration": totalDuration,
            "averageMVPScore": averageMVPScore,
            "highestMVPScore": highestMVPScore,
            "currentStreak": currentStreak,
            "longestStreak": longestStreak,
            "totalCalories": totalCalories
        ]
        
        if let favoritePlayTime = favoritePlayTime {
            data["favoritePlayTime"] = favoritePlayTime
        }
        
        if let lastGameDate = lastGameDate {
            data["lastGameDate"] = lastGameDate
        }
        
        return data
    }
}